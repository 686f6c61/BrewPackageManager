//
//  PackagesCatalogStore.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation
import Observation
import OSLog

/// Fuente de verdad del catálogo de paquetes instalados.
///
/// Posee el ciclo de refresco contra Homebrew (con throttling y cola de
/// peticiones), el estado de pines, la caché de disco para el arranque y el
/// bucle de auto-refresh. No conoce visibilidad ni selección: publica cada
/// snapshot nuevo a través de `onPackagesReplaced` y delega los errores no
/// fatales en `reportError`.
@MainActor
@Observable
final class PackagesCatalogStore {

    // MARK: - Properties

    /// Logger for tracking store operations and debugging.
    private let logger = Logger(subsystem: "BrewPackageManager", category: "PackagesCatalogStore")

    /// Client for executing Homebrew package commands.
    private let client: BrewPackagesClientProtocol

    /// The current loading state of the packages list.
    var state: PackagesState = .idle

    /// When the package list was last refreshed.
    var lastRefresh: Date?

    /// Minimum time between refreshes to prevent excessive API calls.
    private let minimumRefreshInterval: TimeInterval = 10

    /// Whether a refresh operation is currently running.
    private var refreshInFlight = false

    /// Whether a refresh has been requested while another is in progress.
    private var pendingRefreshRequest = false

    /// Last known set of pinned formula names (short and full).
    private var pinnedFormulaNames: Set<String> = []

    /// Active auto-refresh task configured for current settings.
    private var autoRefreshTask: Task<Void, Never>?

    /// Last auto-refresh configuration used to avoid duplicate loops.
    private var autoRefreshConfiguration: (intervalSeconds: Int, debugMode: Bool)?

    /// Whether cached packages have been restored on first load.
    private var restoredCache = false

    /// Background task for saving cache to disk.
    private var cacheSaveTask: Task<Void, Never>?

    // MARK: - Callbacks

    /// Invocado con cada snapshot nuevo (refresh o caché) antes de publicar
    /// el estado, para que la raíz reconcilie visibilidad y selección.
    @ObservationIgnored var onPackagesReplaced: (([BrewPackage]) -> Void)?

    /// Devuelve el número de actualizaciones visibles tras reconciliar;
    /// lo cablea la raíz y se usa solo para el registro en histórico.
    /// Devuelve `nil` si el dato no está disponible, en cuyo caso el
    /// histórico registra el total sin filtrar y lo etiqueta como tal.
    @ObservationIgnored var visibleUpdatesProvider: (() -> Int?)?

    /// Canal para errores que no impiden mostrar los datos en caché.
    @ObservationIgnored var reportError: ((AppError) -> Void)?

    // MARK: - Computed Properties

    /// Whether the initial package load is in progress.
    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    /// Whether a refresh operation is currently in progress.
    var isRefreshing: Bool {
        refreshInFlight
    }

    /// The currently loaded packages, or an empty array if not loaded.
    var packages: [BrewPackage] {
        switch state {
        case .loaded(let packages), .refreshing(let packages):
            packages
        default:
            []
        }
    }

    /// Packages that have updates available.
    var outdatedPackages: [BrewPackage] {
        packages.filter { $0.hasUpdate }
    }

    /// Number of packages with updates available.
    var outdatedCount: Int {
        outdatedPackages.count
    }

    /// The error from the current state, if any.
    var error: AppError? {
        if case .error(let error) = state { return error }
        return nil
    }

    /// Whether Homebrew is available on the system.
    var isBrewAvailable: Bool {
        if case .error(.brewNotFound) = state { return false }
        return true
    }

    // MARK: - Initialization

    /// Initializes the catalog with a Homebrew client.
    ///
    /// - Parameter client: The client to use for Homebrew operations.
    init(client: BrewPackagesClientProtocol) {
        self.client = client
    }

    // MARK: - Public Methods

    /// Refreshes the list of packages from Homebrew.
    ///
    /// This method queries Homebrew for installed packages and their update status.
    /// It includes throttling to prevent excessive refreshes and caching for faster startup.
    ///
    /// - Parameters:
    ///   - debugMode: Whether to run commands in debug mode with verbose output.
    ///   - force: Whether to bypass throttling and force an immediate refresh.
    func refresh(debugMode: Bool = false, force: Bool = false) async {
        restoreCachedPackagesIfNeeded()

        if refreshInFlight {
            pendingRefreshRequest = true
            logger.debug("Refresh already in progress, queueing")
            return
        }

        // Throttle unless forced
        if !force, let lastRefresh, Date().timeIntervalSince(lastRefresh) < minimumRefreshInterval {
            logger.debug("Refresh throttled")
            return
        }

        refreshInFlight = true
        defer { refreshInFlight = false }

        let previousState = state
        let existingPackages: [BrewPackage]? = switch previousState {
        case .loaded(let packages), .refreshing(let packages):
            packages
        default:
            nil
        }

        if let existingPackages {
            state = .refreshing(existingPackages)
        } else {
            state = .loading
        }

        logger.info("Refreshing packages list")

        do {
            // Los tres comandos de brew son independientes entre sí: en
            // paralelo el refresco tarda la mitad que en serie (~1,2 s vs ~2,5 s).
            async let installedTask = client.listInstalledPackages(debugMode: debugMode)
            async let outdatedTask = client.listOutdatedPackages(debugMode: debugMode)
            async let pinnedTask = refreshPinnedFormulaNames(debugMode: debugMode)

            let installed = try await installedTask
            let outdatedSet = Set(try await outdatedTask)
            let pinnedNames = await pinnedTask
            let packages = installed.map {
                mergedPackage($0, outdatedSet: outdatedSet, pinnedNames: pinnedNames)
            }
            publishPackagesReplaced(packages)

            let now = Date()
            lastRefresh = now
            persistPackagesCache(packages: packages, lastRefresh: now)

            state = .loaded(packages)
            // El contador de actualizaciones visibles lo aporta la raíz; si no
            // está disponible se degrada al total sin filtrar, dejando traza y
            // etiquetándolo para no falsear el histórico.
            let updatesDetail: String
            if let visibleUpdates = visibleUpdatesProvider?() {
                updatesDetail = "\(visibleUpdates) visible updates"
            } else {
                logger.warning("visibleUpdatesProvider no disponible; el histórico usa el total sin filtrar")
                updatesDetail = "\(packages.filter(\.hasUpdate).count) outdated (unfiltered)"
            }
            logger.info("Loaded \(packages.count) packages (\(updatesDetail))")
            logHistory(
                operation: .refresh,
                packageName: "packages",
                details: "Loaded \(packages.count) packages (\(updatesDetail))",
                success: true
            )
        } catch is CancellationError {
            state = previousState
            logger.debug("Refresh cancelled")
        } catch let error as AppError {
            if case .cancelled = error {
                state = previousState
                logger.debug("Refresh cancelled")
                return
            }

            if let existingPackages {
                state = .loaded(existingPackages)
                report(error)
            } else {
                handleError(error)
            }
            logHistory(operation: .refresh, packageName: "packages", details: error.localizedDescription, success: false)
        } catch let error as BrewLocatorError {
            if let existingPackages {
                state = .loaded(existingPackages)
                logger.error("Brew not found: \(error.localizedDescription)")
            } else {
                state = .error(.brewNotFound)
                logger.error("Brew not found: \(error.localizedDescription)")
            }
            logHistory(operation: .refresh, packageName: "packages", details: error.localizedDescription, success: false)
        } catch {
            if let existingPackages {
                state = .loaded(existingPackages)
                report(.brewFailed(exitCode: -1, stderr: error.localizedDescription))
            } else {
                state = .error(.brewFailed(exitCode: -1, stderr: error.localizedDescription))
            }
            logger.error("Unknown error: \(error.localizedDescription)")
            logHistory(operation: .refresh, packageName: "packages", details: error.localizedDescription, success: false)
        }

        if pendingRefreshRequest {
            pendingRefreshRequest = false
            await refresh(debugMode: debugMode, force: true)
        }
    }

    /// Runs an auto-refresh loop that periodically updates the package list.
    ///
    /// This method performs an initial refresh and then continues refreshing at the
    /// specified interval until the task is cancelled.
    ///
    /// - Parameters:
    ///   - intervalSeconds: Seconds between refreshes. If 0 or less, no auto-refresh occurs.
    ///   - debugMode: Whether to run commands in debug mode with verbose output.
    func runAutoRefresh(intervalSeconds: Int, debugMode: Bool = false) async {
        await refresh(debugMode: debugMode)

        guard intervalSeconds > 0 else { return }

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(intervalSeconds))
            } catch {
                return
            }

            await refresh(debugMode: debugMode)
        }
    }

    /// Configures a single auto-refresh loop for the given settings.
    ///
    /// Calling this repeatedly with the same settings is a no-op while a loop is active.
    func configureAutoRefresh(intervalSeconds: Int, debugMode: Bool = false) {
        let normalizedInterval = max(0, intervalSeconds)
        let configuration: (intervalSeconds: Int, debugMode: Bool) = (normalizedInterval, debugMode)

        if let current = autoRefreshConfiguration, current == configuration {
            if autoRefreshTask != nil {
                return
            }

            if normalizedInterval == 0, lastRefresh != nil {
                return
            }
        }

        autoRefreshConfiguration = configuration
        autoRefreshTask?.cancel()
        autoRefreshTask = Task { [weak self] in
            guard let self else { return }
            await self.runAutoRefresh(intervalSeconds: normalizedInterval, debugMode: debugMode)
            await MainActor.run {
                if let currentConfiguration = self.autoRefreshConfiguration,
                   currentConfiguration == configuration {
                    self.autoRefreshTask = nil
                }
            }
        }
    }

    /// Returns whether a package is pinned in Homebrew.
    func isPackagePinned(_ package: BrewPackage) -> Bool {
        isPackagePinned(package, pinnedNames: pinnedFormulaNames)
    }

    /// Returns whether a package is pinned given an explicit pinned-name set.
    ///
    /// Lo usa el upgrade masivo, que refresca la lista de pines justo antes
    /// de decidir qué paquetes procesa.
    func isPackagePinned(_ package: BrewPackage, pinnedNames: Set<String>) -> Bool {
        guard package.type == .formula else { return false }
        if package.pinnedVersion != nil { return true }
        return pinnedNames.contains(package.name) || pinnedNames.contains(package.fullName)
    }

    /// Loads pinned formula names from Homebrew and keeps last known state.
    func refreshPinnedFormulaNames(debugMode: Bool) async -> Set<String> {
        do {
            let rawNames = try await client.listPinnedPackages(debugMode: debugMode)
            let normalized = normalizePinnedNames(rawNames)
            pinnedFormulaNames = normalized
            return normalized
        } catch {
            logger.warning("Failed to list pinned packages: \(error.localizedDescription)")
            return pinnedFormulaNames
        }
    }

    // MARK: - Private Methods

    /// Normalizes pinned names to include both short name and full name variants.
    private func normalizePinnedNames(_ names: Set<String>) -> Set<String> {
        var normalized = Set<String>()
        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            normalized.insert(trimmed)
            if let shortName = trimmed.split(separator: "/").last {
                normalized.insert(String(shortName))
            }
        }
        return normalized
    }

    /// Merges outdated and pinned metadata into a package snapshot.
    private func mergedPackage(
        _ package: BrewPackage,
        outdatedSet: Set<String>,
        pinnedNames: Set<String>
    ) -> BrewPackage {
        let pinned = isPackagePinned(package, pinnedNames: pinnedNames)
        return BrewPackage(
            name: package.name,
            fullName: package.fullName,
            desc: package.desc,
            homepage: package.homepage,
            type: package.type,
            installedVersion: package.installedVersion,
            currentVersion: package.currentVersion,
            isOutdated: outdatedSet.contains(package.name),
            pinnedVersion: pinned ? (package.pinnedVersion ?? package.installedVersion) : nil,
            tap: package.tap
        )
    }

    /// Sets the state to error and logs the error.
    ///
    /// - Parameter error: The error to handle.
    private func handleError(_ error: AppError) {
        state = .error(error)
        logger.error("Error: \(error.localizedDescription)")
    }

    /// Restores cached packages on first load.
    ///
    /// This method runs once to load cached package data, providing faster
    /// startup by showing cached data before the first refresh completes.
    private func restoreCachedPackagesIfNeeded() {
        guard !restoredCache else { return }
        restoredCache = true

        Task {
            let cached = await Task.detached(priority: .utility) {
                PackagesDiskCache.load()
            }.value

            guard let cached else { return }

            publishPackagesReplaced(cached.packages)
            state = .loaded(cached.packages)
            lastRefresh = cached.lastRefresh
        }
    }

    /// Publica un snapshot nuevo a la raíz, con red de seguridad si el
    /// cableado falta: sin reconciliación, los ocultos y la selección se
    /// degradan en silencio, así que en debug se detiene la ejecución.
    private func publishPackagesReplaced(_ packages: [BrewPackage]) {
        guard let onPackagesReplaced else {
            logger.fault("onPackagesReplaced sin cablear: visibilidad y selección no se reconcilian")
            assertionFailure("PackagesCatalogStore usado fuera de PackagesStore")
            return
        }
        onPackagesReplaced(packages)
    }

    /// Emite un error no fatal hacia la raíz, con red de seguridad si el
    /// cableado falta: en debug detiene la ejecución y en release deja traza.
    private func report(_ error: AppError) {
        guard let reportError else {
            logger.fault("reportError sin cablear: se pierde \(error.localizedDescription)")
            assertionFailure("PackagesCatalogStore usado fuera de PackagesStore")
            return
        }
        reportError(error)
    }

    /// Persists packages to the disk cache in the background.
    ///
    /// This method runs asynchronously at utility priority to avoid blocking
    /// the main thread. It ensures only one cache save operation runs at a time.
    ///
    /// - Parameters:
    ///   - packages: The packages to cache.
    ///   - lastRefresh: The timestamp of the refresh.
    private func persistPackagesCache(packages: [BrewPackage], lastRefresh: Date) {
        let previousTask = cacheSaveTask
        cacheSaveTask = Task.detached(priority: .utility) {
            _ = await previousTask?.result
            try? PackagesDiskCache.save(packages: packages, lastRefresh: lastRefresh)
        }
    }

    /// Logs an operation to history without blocking UI flow.
    private func logHistory(
        operation: HistoryEntry.OperationType,
        packageName: String,
        details: String? = nil,
        success: Bool = true
    ) {
        Task {
            await HistoryStore.logOperation(
                operation: operation,
                packageName: packageName,
                details: details,
                success: success
            )
        }
    }
}
