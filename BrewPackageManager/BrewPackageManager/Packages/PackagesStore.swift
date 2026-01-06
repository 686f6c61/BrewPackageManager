//
//  PackagesStore.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//  Version: 1.5.0
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation
import Observation
import OSLog

/// The main store for managing package state and operations.
///
/// This observable class coordinates all package-related operations including:
/// - Loading and refreshing package lists
/// - Tracking selection state for bulk operations
/// - Managing upgrade and uninstall operations
/// - Caching package data to disk
/// - Auto-refresh functionality
///
/// All methods must be called on the main actor as this class updates SwiftUI state.
@MainActor
@Observable
final class PackagesStore {

    // MARK: - Properties

    /// Logger for tracking store operations and debugging.
    private let logger = Logger(subsystem: "BrewPackageManager", category: "PackagesStore")

    /// The current loading state of the packages list.
    var state: PackagesState = .idle

    /// Non-fatal errors that don't prevent showing cached data.
    var nonFatalError: AppError?

    // MARK: - Selection State

    /// Package IDs that are currently selected for bulk updates.
    var selectedPackageIDs: Set<String> = []

    // MARK: - Operation Tracking

    /// Tracks the status of operations for individual packages.
    var packageOperations: [String: PackageOperation] = [:]

    /// Whether a bulk upgrade operation is currently in progress.
    var isUpgradingSelected = false

    /// Progress information for the current bulk upgrade operation.
    var upgradeProgress: UpgradeProgress?

    // MARK: - Package Detail

    /// Detailed information about a selected package, if loaded.
    private(set) var selectedPackageInfo: BrewPackageInfo?

    // MARK: - Search State

    /// The current search state.
    var searchState: SearchState = .idle

    /// Search results with package info loaded.
    private(set) var searchResults: [SearchResult] = []

    /// Currently selected package type filter for search.
    var searchTypeFilter: PackageType? = nil

    /// Packages currently being installed (keyed by package name).
    var installOperations: [String: PackageOperation] = [:]

    /// Number of results to show per page.
    private let searchPageSize = 15

    // MARK: - Refresh Tracking

    /// When the package list was last refreshed.
    var lastRefresh: Date?

    /// Minimum time between refreshes to prevent excessive API calls.
    private let minimumRefreshInterval: TimeInterval = 10

    /// Whether a refresh operation is currently running.
    private var refreshInFlight = false

    /// Whether a refresh has been requested while another is in progress.
    private var pendingRefreshRequest = false

    // MARK: - Cache Management

    /// Whether cached packages have been restored on first load.
    private var restoredCache = false

    /// Background task for saving cache to disk.
    private var cacheSaveTask: Task<Void, Never>?

    // MARK: - Dependencies

    /// Client for executing Homebrew package commands.
    private let client: BrewPackagesClientProtocol

    // MARK: - Nested Types

    /// Progress information for bulk upgrade operations.
    struct UpgradeProgress: Sendable {
        /// Number of packages that have completed (successfully or with error).
        let completed: Int

        /// Total number of packages to upgrade.
        let total: Int

        /// The name of the package currently being upgraded.
        let currentPackage: String?

        /// Number of packages that failed to upgrade.
        let failed: Int
    }

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

    /// Initializes the store with a Homebrew client.
    ///
    /// - Parameter client: The client to use for Homebrew operations. Defaults to a new BrewPackagesClient.
    init(client: BrewPackagesClientProtocol = BrewPackagesClient()) {
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
            // Get all installed packages
            let installed = try await client.listInstalledPackages(debugMode: debugMode)

            // Get outdated package names
            let outdatedNames = try await client.listOutdatedPackages(debugMode: debugMode)
            let outdatedSet = Set(outdatedNames)

            // Merge the data
            var packages = installed
            for index in packages.indices {
                packages[index].isOutdated = outdatedSet.contains(packages[index].name)
            }

            let now = Date()
            lastRefresh = now
            persistPackagesCache(packages: packages, lastRefresh: now)

            state = .loaded(packages)
            logger.info("Loaded \(packages.count) packages (\(self.outdatedCount) outdated)")
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
                nonFatalError = error
            } else {
                handleError(error)
            }
        } catch let error as BrewLocatorError {
            if let existingPackages {
                state = .loaded(existingPackages)
                logger.error("Brew not found: \(error.localizedDescription)")
            } else {
                state = .error(.brewNotFound)
                logger.error("Brew not found: \(error.localizedDescription)")
            }
        } catch {
            if let existingPackages {
                state = .loaded(existingPackages)
                nonFatalError = .brewFailed(exitCode: -1, stderr: error.localizedDescription)
            } else {
                state = .error(.brewFailed(exitCode: -1, stderr: error.localizedDescription))
            }
            logger.error("Unknown error: \(error.localizedDescription)")
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

    /// Toggles selection state for a package.
    ///
    /// - Parameter packageID: The ID of the package to toggle.
    func toggleSelection(for packageID: String) {
        if selectedPackageIDs.contains(packageID) {
            selectedPackageIDs.remove(packageID)
        } else {
            selectedPackageIDs.insert(packageID)
        }
    }

    /// Selects all packages that have updates available.
    func selectAllOutdated() {
        selectedPackageIDs = Set(outdatedPackages.map { $0.id })
    }

    /// Deselects all packages.
    func deselectAll() {
        selectedPackageIDs.removeAll()
    }

    /// Upgrades all selected packages.
    ///
    /// This method upgrades packages sequentially, tracking progress and handling errors
    /// for each package. After completion, it refreshes the package list and clears
    /// selections if all upgrades succeeded.
    ///
    /// - Parameter debugMode: Whether to run commands in debug mode with verbose output.
    func upgradeSelected(debugMode: Bool = false) async {
        let selectedPackages = packages.filter { selectedPackageIDs.contains($0.id) }
        guard !selectedPackages.isEmpty else { return }

        logger.info("Upgrading \(selectedPackages.count) selected packages")

        isUpgradingSelected = true
        upgradeProgress = UpgradeProgress(completed: 0, total: selectedPackages.count, currentPackage: nil, failed: 0)

        var completed = 0
        var failed = 0

        for package in selectedPackages {
            upgradeProgress = UpgradeProgress(
                completed: completed,
                total: selectedPackages.count,
                currentPackage: package.name,
                failed: failed
            )

            packageOperations[package.id] = PackageOperation(status: .running, error: nil, diagnostics: nil)

            do {
                try await client.upgradePackage(package.name, debugMode: debugMode)
                packageOperations[package.id] = PackageOperation(status: .succeeded, error: nil, diagnostics: nil)
            } catch let error as AppError {
                if case .cancelled = error {
                    logger.debug("Upgrade cancelled")
                    packageOperations[package.id] = .idle
                    break
                }
                failed += 1
                packageOperations[package.id] = PackageOperation(
                    status: .failed,
                    error: error,
                    diagnostics: "Failed to upgrade \(package.name): \(error.localizedDescription)"
                )
            } catch {
                failed += 1
                let appError = AppError.brewFailed(exitCode: -1, stderr: error.localizedDescription)
                packageOperations[package.id] = PackageOperation(
                    status: .failed,
                    error: appError,
                    diagnostics: "Failed to upgrade \(package.name): \(error.localizedDescription)"
                )
            }

            completed += 1
        }

        upgradeProgress = UpgradeProgress(
            completed: completed,
            total: selectedPackages.count,
            currentPackage: nil,
            failed: failed
        )

        isUpgradingSelected = false

        // Refresh to get updated state
        await refresh(debugMode: debugMode, force: true)

        // Clear selections after successful upgrade
        if failed == 0 {
            deselectAll()
        }
    }

    /// Uninstalls a package.
    ///
    /// This method removes the specified package and refreshes the package list
    /// upon successful completion.
    ///
    /// - Parameters:
    ///   - packageID: The ID of the package to uninstall.
    ///   - debugMode: Whether to run commands in debug mode with verbose output.
    func uninstallPackage(_ packageID: String, debugMode: Bool = false) async {
        guard let package = packages.first(where: { $0.id == packageID }) else { return }

        logger.info("Uninstalling package \(package.name)")

        packageOperations[packageID] = PackageOperation(status: .running, error: nil, diagnostics: nil)

        do {
            try await client.uninstallPackage(package.name, debugMode: debugMode)
            packageOperations[packageID] = PackageOperation(status: .succeeded, error: nil, diagnostics: nil)

            // Refresh to update package list
            await refresh(debugMode: debugMode, force: true)

            // Clear the operation status after refresh
            packageOperations.removeValue(forKey: packageID)
        } catch let error as AppError {
            if case .cancelled = error {
                logger.debug("Uninstall cancelled")
                packageOperations[packageID] = .idle
                return
            }
            packageOperations[packageID] = PackageOperation(
                status: .failed,
                error: error,
                diagnostics: "Failed to uninstall \(package.name): \(error.localizedDescription)"
            )
        } catch {
            let appError = AppError.brewFailed(exitCode: -1, stderr: error.localizedDescription)
            packageOperations[packageID] = PackageOperation(
                status: .failed,
                error: appError,
                diagnostics: "Failed to uninstall \(package.name): \(error.localizedDescription)"
            )
        }
    }

    /// Fetches detailed information about a package.
    ///
    /// The fetched information is stored in `selectedPackageInfo` for display.
    ///
    /// - Parameters:
    ///   - packageName: The name of the package to query.
    ///   - debugMode: Whether to run commands in debug mode with verbose output.
    func fetchPackageInfo(_ packageName: String, debugMode: Bool = false) async {
        logger.info("Fetching info for \(packageName)")

        do {
            selectedPackageInfo = try await client.getPackageInfo(packageName, debugMode: debugMode)
            logger.info("Fetched info for \(packageName)")
        } catch let error as AppError {
            if case .cancelled = error {
                logger.debug("Fetch info cancelled")
                return
            }
            nonFatalError = error
        } catch {
            nonFatalError = .brewFailed(exitCode: -1, stderr: error.localizedDescription)
            logger.error("Fetch info failed: \(error.localizedDescription)")
        }
    }

    /// Clears the selected package information.
    func clearPackageInfo() {
        selectedPackageInfo = nil
    }

    /// Dismisses the current non-fatal error.
    func dismissError() {
        nonFatalError = nil
    }

    /// Exports the package list to CSV format.
    ///
    /// The CSV includes columns for name, full name, type, versions, outdated status,
    /// tap, description, and homepage. Fields containing commas or quotes are properly escaped.
    ///
    /// - Returns: A CSV-formatted string of all packages.
    func exportToCSV() -> String {
        var csv = "Name,Full Name,Type,Installed Version,Current Version,Outdated,Tap,Description,Homepage\n"

        for package in packages {
            let name = escapeCSV(package.name)
            let fullName = escapeCSV(package.fullName)
            let type = escapeCSV(package.type.rawValue)
            let installedVersion = escapeCSV(package.installedVersion)
            let currentVersion = escapeCSV(package.currentVersion ?? "")
            let outdated = package.isOutdated ? "Yes" : "No"
            let tap = escapeCSV(package.tap ?? "")
            let desc = escapeCSV(package.desc ?? "")
            let homepage = escapeCSV(package.homepage ?? "")

            csv += "\(name),\(fullName),\(type),\(installedVersion),\(currentVersion),\(outdated),\(tap),\(desc),\(homepage)\n"
        }

        return csv
    }

    /// Escapes a value for CSV format.
    ///
    /// Wraps values in quotes if they contain commas, quotes, or newlines, and
    /// escapes any internal quotes by doubling them.
    ///
    /// - Parameter value: The string to escape.
    /// - Returns: The escaped string suitable for CSV.
    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacing("\"", with: "\"\""))\""
        }
        return value
    }

    // MARK: - Private Methods

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

            state = .loaded(cached.packages)
            lastRefresh = cached.lastRefresh
        }
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

    // MARK: - Search Operations

    /// Performs a package search.
    ///
    /// This method queries Homebrew for packages matching the given search term.
    /// Results are limited to the first page (15 results by default).
    ///
    /// - Parameters:
    ///   - query: The search term to query.
    ///   - debugMode: Whether to run in debug mode.
    func search(query: String, debugMode: Bool = false) async {
        guard !query.isEmpty else {
            searchState = .idle
            searchResults = []
            return
        }

        logger.info("Searching for packages: \(query)")
        searchState = .searching(query: query)

        do {
            // Search for packages
            let names = try await client.searchPackages(
                query,
                type: searchTypeFilter,
                debugMode: debugMode
            )

            // Get installed package names for comparison
            let installedNames = Set(packages.map { $0.name })

            // Create search results (limit to first page)
            let hasMore = names.count > searchPageSize
            let pageNames = Array(names.prefix(searchPageSize))

            searchResults = pageNames.map { name in
                // Determine type - check if it's a known installed package first
                let type: PackageType
                if let installedPackage = packages.first(where: { $0.name == name }) {
                    type = installedPackage.type
                } else {
                    // Default to formula if no filter, otherwise use the filter
                    type = searchTypeFilter ?? .formula
                }

                return SearchResult(
                    name: name,
                    type: type,
                    isInstalled: installedNames.contains(name)
                )
            }

            searchState = .loaded(query: query, results: searchResults, hasMore: hasMore)
            logger.info("Found \(names.count) packages (\(self.searchResults.count) shown)")

        } catch let error as AppError {
            if case .cancelled = error {
                logger.debug("Search cancelled")
                searchState = .idle
                return
            }
            searchState = .error(error)
            logger.error("Search failed: \(error.localizedDescription)")
        } catch {
            let appError = AppError.brewFailed(exitCode: -1, stderr: error.localizedDescription)
            searchState = .error(appError)
            logger.error("Search failed: \(error.localizedDescription)")
        }
    }

    /// Clears search results and resets to idle state.
    func clearSearch() {
        searchState = .idle
        searchResults = []
        searchTypeFilter = nil
    }

    /// Fetches detailed info for a search result.
    ///
    /// This method loads package information and caches it in the search result.
    ///
    /// - Parameters:
    ///   - result: The search result to fetch info for.
    ///   - debugMode: Whether to run in debug mode.
    func fetchSearchResultInfo(_ result: SearchResult, debugMode: Bool = false) async {
        guard let index = searchResults.firstIndex(where: { $0.id == result.id }) else {
            return
        }

        // Skip if already loaded
        if searchResults[index].info != nil {
            return
        }

        do {
            let info = try await client.getPackageInfo(result.name, debugMode: debugMode)
            searchResults[index].info = info
        } catch {
            logger.error("Failed to fetch info for \(result.name): \(error.localizedDescription)")
        }
    }

    // MARK: - Installation Operations

    /// Installs a package from search results.
    ///
    /// This method installs the specified package, tracks installation progress,
    /// and automatically refreshes the package list upon successful completion.
    ///
    /// - Parameters:
    ///   - result: The search result representing the package to install.
    ///   - debugMode: Whether to run in debug mode.
    func installPackage(_ result: SearchResult, debugMode: Bool = false) async {
        logger.info("Installing package \(result.name)")

        installOperations[result.name] = PackageOperation(
            status: .running,
            error: nil,
            diagnostics: "Installing \(result.name)..."
        )

        do {
            try await client.installPackage(result.name, type: result.type, debugMode: debugMode)

            installOperations[result.name] = PackageOperation(
                status: .succeeded,
                error: nil,
                diagnostics: nil
            )

            // Refresh package list to show newly installed package
            await refresh(debugMode: debugMode, force: true)

            // Update search results to reflect installation
            if let index = searchResults.firstIndex(where: { $0.id == result.id }) {
                searchResults[index] = SearchResult(
                    name: result.name,
                    type: result.type,
                    isInstalled: true
                )
            }

            // Clear operation after successful refresh
            try? await Task.sleep(for: .seconds(2))
            installOperations.removeValue(forKey: result.name)

        } catch let error as AppError {
            if case .cancelled = error {
                logger.debug("Installation cancelled")
                installOperations[result.name] = .idle
                return
            }

            installOperations[result.name] = PackageOperation(
                status: .failed,
                error: error,
                diagnostics: "Failed to install \(result.name): \(error.localizedDescription)"
            )
        } catch {
            let appError = AppError.brewFailed(exitCode: -1, stderr: error.localizedDescription)
            installOperations[result.name] = PackageOperation(
                status: .failed,
                error: appError,
                diagnostics: "Failed to install \(result.name): \(error.localizedDescription)"
            )
        }
    }

    /// Clears the installation operation status for a package.
    ///
    /// - Parameter packageName: The name of the package to clear the operation for.
    func clearInstallOperation(for packageName: String) {
        installOperations.removeValue(forKey: packageName)
    }
}
