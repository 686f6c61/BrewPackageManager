//
//  PackagesStore.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//  Version: 1.6.0
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

    struct HiddenItem: Identifiable, Equatable {
        enum Kind: String, Equatable {
            case package
            case update

            var title: String {
                switch self {
                case .package:
                    "Hidden Package"
                case .update:
                    "Hidden Update"
                }
            }
        }

        let package: BrewPackage
        let kind: Kind

        var id: String { "\(kind.rawValue):\(package.id)" }
    }

    // MARK: - Properties

    /// Logger for tracking store operations and debugging.
    private let logger = Logger(subsystem: "BrewPackageManager", category: "PackagesStore")

    /// Defaults storage for lightweight UI preferences owned by the store.
    private let defaults: UserDefaults

    /// Keys for package visibility preferences persisted by the store.
    private enum DefaultsKeys {
        static let hiddenPackageIDs = "hiddenPackageIDs"
        static let hiddenUpdatePackageIDs = "hiddenUpdatePackageIDs"
    }

    /// The current loading state of the packages list.
    var state: PackagesState = .idle

    /// Non-fatal errors that don't prevent showing cached data.
    var nonFatalError: AppError?

    // MARK: - Selection State

    /// Package IDs that are currently selected for bulk updates.
    var selectedPackageIDs: Set<String> = []

    /// Package IDs hidden from the main packages list.
    private(set) var hiddenPackageIDs: Set<String> = [] {
        didSet { persistSet(hiddenPackageIDs, forKey: DefaultsKeys.hiddenPackageIDs) }
    }

    /// Package IDs whose update state is hidden while keeping the package visible.
    private(set) var hiddenUpdatePackageIDs: Set<String> = [] {
        didSet { persistSet(hiddenUpdatePackageIDs, forKey: DefaultsKeys.hiddenUpdatePackageIDs) }
    }

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

    /// Monotonic token used to ignore stale search responses.
    private var activeSearchRequestID = 0

    // MARK: - Refresh Tracking

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

    // MARK: - Update Checking

    /// Update checker for managing application updates.
    private let updateChecker = UpdateChecker()

    /// Current update check result.
    var updateCheckResult: UpdateCheckResult?

    /// Whether an update check is in progress.
    var isCheckingForUpdates = false

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

    /// Packages visible in the main list after applying hidden package rules.
    var visiblePackages: [BrewPackage] {
        packages.filter { !isPackageHidden($0) }
    }

    /// Packages with user-visible, actionable updates.
    var visibleOutdatedPackages: [BrewPackage] {
        visiblePackages.filter { hasVisibleUpdate($0) }
    }

    /// Number of user-visible, actionable updates.
    var visibleOutdatedCount: Int {
        visibleOutdatedPackages.count
    }

    /// Hidden packages and updates that are still installed and can be managed in the UI.
    var hiddenItems: [HiddenItem] {
        packages
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            .compactMap { package in
                if hiddenPackageIDs.contains(package.id) {
                    return HiddenItem(package: package, kind: .package)
                }
                if hiddenUpdatePackageIDs.contains(package.id) {
                    return HiddenItem(package: package, kind: .update)
                }
                return nil
            }
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
    /// - Parameters:
    ///   - client: The client to use for Homebrew operations. Defaults to a new BrewPackagesClient.
    ///   - defaults: The defaults store to use for visibility preferences. Defaults to `.standard`.
    init(
        client: BrewPackagesClientProtocol = BrewPackagesClient(),
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.defaults = defaults
        hiddenPackageIDs = Self.loadStoredSet(from: defaults, forKey: DefaultsKeys.hiddenPackageIDs)
        hiddenUpdatePackageIDs = Self.loadStoredSet(from: defaults, forKey: DefaultsKeys.hiddenUpdatePackageIDs)
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
            let pinnedNames = await fetchPinnedFormulaNames(debugMode: debugMode)
            let packages = installed.map {
                mergedPackage($0, outdatedSet: outdatedSet, pinnedNames: pinnedNames)
            }
            reconcileLocalState(with: packages)

            let now = Date()
            lastRefresh = now
            persistPackagesCache(packages: packages, lastRefresh: now)

            state = .loaded(packages)
            logger.info("Loaded \(packages.count) packages (\(self.visibleOutdatedCount) visible updates)")
            logHistory(
                operation: .refresh,
                packageName: "packages",
                details: "Loaded \(packages.count) packages (\(self.visibleOutdatedCount) visible updates)",
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
                nonFatalError = error
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
                nonFatalError = .brewFailed(exitCode: -1, stderr: error.localizedDescription)
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

    /// Toggles selection state for a package.
    ///
    /// - Parameter packageID: The ID of the package to toggle.
    func toggleSelection(for packageID: String) {
        guard let package = packages.first(where: { $0.id == packageID }), hasVisibleUpdate(package) else {
            selectedPackageIDs.remove(packageID)
            return
        }

        if selectedPackageIDs.contains(packageID) {
            selectedPackageIDs.remove(packageID)
        } else {
            selectedPackageIDs.insert(packageID)
        }
    }

    /// Returns whether a package is pinned in Homebrew.
    func isPackagePinned(_ package: BrewPackage) -> Bool {
        isPackagePinned(package, pinnedNames: pinnedFormulaNames)
    }

    /// Returns whether the package is hidden from the main packages list.
    func isPackageHidden(_ package: BrewPackage) -> Bool {
        hiddenPackageIDs.contains(package.id)
    }

    /// Returns whether the package's update state is hidden.
    func isUpdateHidden(_ package: BrewPackage) -> Bool {
        hiddenUpdatePackageIDs.contains(package.id)
    }

    /// Returns whether a package has a visible, actionable update.
    func hasVisibleUpdate(_ package: BrewPackage) -> Bool {
        guard package.hasUpdate else { return false }
        guard !isPackageHidden(package), !isUpdateHidden(package) else { return false }
        return !isPackagePinned(package)
    }

    /// Returns whether the package has an update that is blocked because it is pinned.
    func showsPinnedUpdateNotice(_ package: BrewPackage) -> Bool {
        guard package.hasUpdate else { return false }
        guard !isPackageHidden(package), !isUpdateHidden(package) else { return false }
        return isPackagePinned(package)
    }

    /// Hides the package from the installed packages list.
    func hidePackage(_ package: BrewPackage) {
        hiddenPackageIDs.insert(package.id)
        hiddenUpdatePackageIDs.remove(package.id)
        selectedPackageIDs.remove(package.id)
    }

    /// Restores a previously hidden package.
    func unhidePackage(_ packageID: String) {
        hiddenPackageIDs.remove(packageID)
    }

    /// Hides the update state for a package while keeping the package visible.
    func hideUpdate(for package: BrewPackage) {
        guard package.hasUpdate, !isPackageHidden(package) else { return }
        hiddenUpdatePackageIDs.insert(package.id)
        selectedPackageIDs.remove(package.id)
    }

    /// Restores a previously hidden update.
    func unhideUpdate(for packageID: String) {
        hiddenUpdatePackageIDs.remove(packageID)
    }

    /// Selects all packages that have updates available.
    func selectAllOutdated() {
        selectedPackageIDs = Set(visibleOutdatedPackages.map(\.id))
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
        guard !isUpgradingSelected else { return }

        let selectedPackages = packages.filter {
            selectedPackageIDs.contains($0.id) && !isPackageHidden($0) && !isUpdateHidden($0)
        }
        guard !selectedPackages.isEmpty else { return }

        let pinnedNames = await fetchPinnedFormulaNames(debugMode: debugMode)
        let pinnedPackages = selectedPackages.filter { isPackagePinned($0, pinnedNames: pinnedNames) }
        let upgradablePackages = selectedPackages.filter { !isPackagePinned($0, pinnedNames: pinnedNames) }

        if !pinnedPackages.isEmpty {
            for package in pinnedPackages {
                let message = "Package '\(package.name)' is pinned. Run 'brew unpin \(package.name)' to upgrade."
                packageOperations[package.id] = PackageOperation(
                    status: .failed,
                    error: .unknown(message),
                    diagnostics: message
                )
                logHistory(operation: .upgrade, packageName: package.name, details: message, success: false)
            }
        }

        if upgradablePackages.isEmpty {
            if !pinnedPackages.isEmpty {
                let names = pinnedPackages.map(\.name).sorted().joined(separator: ", ")
                nonFatalError = .unknown("Selected package(s) are pinned: \(names). Use 'brew unpin <name>' and try again.")
            }
            return
        }

        logger.info("Upgrading \(upgradablePackages.count) selected packages")

        isUpgradingSelected = true
        upgradeProgress = UpgradeProgress(completed: 0, total: upgradablePackages.count, currentPackage: nil, failed: 0)

        var completed = 0
        var failed = 0
        var firstFailure: AppError?

        for package in upgradablePackages {
            upgradeProgress = UpgradeProgress(
                completed: completed,
                total: upgradablePackages.count,
                currentPackage: package.name,
                failed: failed
            )

            packageOperations[package.id] = PackageOperation(status: .running, error: nil, diagnostics: nil)

            do {
                try await client.upgradePackage(package.name, type: package.type, debugMode: debugMode)
                packageOperations[package.id] = PackageOperation(status: .succeeded, error: nil, diagnostics: nil)
                logHistory(operation: .upgrade, packageName: package.name, success: true)
            } catch let error as AppError {
                if case .cancelled = error {
                    logger.debug("Upgrade cancelled")
                    packageOperations[package.id] = .idle
                    logHistory(operation: .upgrade, packageName: package.name, details: "Operation cancelled", success: false)
                    break
                }
                let mappedError = mapUpgradeError(error, packageName: package.name)
                failed += 1
                if firstFailure == nil {
                    firstFailure = mappedError
                }
                packageOperations[package.id] = PackageOperation(
                    status: .failed,
                    error: mappedError,
                    diagnostics: "Failed to upgrade \(package.name): \(mappedError.localizedDescription)"
                )
                logHistory(operation: .upgrade, packageName: package.name, details: mappedError.localizedDescription, success: false)
            } catch {
                failed += 1
                let appError = AppError.brewFailed(exitCode: -1, stderr: error.localizedDescription)
                if firstFailure == nil {
                    firstFailure = appError
                }
                packageOperations[package.id] = PackageOperation(
                    status: .failed,
                    error: appError,
                    diagnostics: "Failed to upgrade \(package.name): \(error.localizedDescription)"
                )
                logHistory(operation: .upgrade, packageName: package.name, details: error.localizedDescription, success: false)
            }

            completed += 1
        }

        upgradeProgress = UpgradeProgress(
            completed: completed,
            total: upgradablePackages.count,
            currentPackage: nil,
            failed: failed
        )

        isUpgradingSelected = false
        upgradeProgress = nil

        // Clear selections after successful upgrade
        if failed == 0 {
            let pinnedIDs = Set(pinnedPackages.map(\.id))
            selectedPackageIDs.subtract(pinnedIDs)
            deselectAll()
        } else if let firstFailure {
            nonFatalError = firstFailure
        }

        if !pinnedPackages.isEmpty, failed == 0 {
            let names = pinnedPackages.map(\.name).sorted().joined(separator: ", ")
            nonFatalError = .unknown("Skipped pinned package(s): \(names). Use 'brew unpin <name>' to upgrade.")
        }

        // Refresh in background so the UI does not appear stuck in an updating state.
        Task {
            await refresh(debugMode: debugMode, force: true)
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
            try await client.uninstallPackage(package.name, type: package.type, debugMode: debugMode)
            packageOperations[packageID] = PackageOperation(status: .succeeded, error: nil, diagnostics: nil)
            logHistory(operation: .uninstall, packageName: package.name, success: true)

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
            logHistory(operation: .uninstall, packageName: package.name, details: error.localizedDescription, success: false)
        } catch {
            let appError = AppError.brewFailed(exitCode: -1, stderr: error.localizedDescription)
            packageOperations[packageID] = PackageOperation(
                status: .failed,
                error: appError,
                diagnostics: "Failed to uninstall \(package.name): \(error.localizedDescription)"
            )
            logHistory(operation: .uninstall, packageName: package.name, details: error.localizedDescription, success: false)
        }
    }

    /// Fetches detailed information about a package.
    ///
    /// The fetched information is stored in `selectedPackageInfo` for display.
    ///
    /// - Parameters:
    ///   - packageName: The name of the package to query.
    ///   - type: Optional package type to disambiguate formula vs cask names.
    ///   - debugMode: Whether to run commands in debug mode with verbose output.
    func fetchPackageInfo(_ packageName: String, type: PackageType? = nil, debugMode: Bool = false) async {
        logger.info("Fetching info for \(packageName)")

        do {
            selectedPackageInfo = try await client.getPackageInfo(packageName, type: type, debugMode: debugMode)
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

    /// Loads a stored set of strings from defaults.
    private static func loadStoredSet(from defaults: UserDefaults, forKey key: String) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    /// Persists a set of strings to defaults using a stable ordering.
    private func persistSet(_ set: Set<String>, forKey key: String) {
        if set.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(set.sorted(), forKey: key)
        }
    }

    /// Loads pinned formula names from Homebrew and keeps last known state.
    private func fetchPinnedFormulaNames(debugMode: Bool) async -> Set<String> {
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

    private func isPackagePinned(_ package: BrewPackage, pinnedNames: Set<String>) -> Bool {
        guard package.type == .formula else { return false }
        if package.pinnedVersion != nil { return true }
        return pinnedNames.contains(package.name) || pinnedNames.contains(package.fullName)
    }

    private func mapUpgradeError(_ error: AppError, packageName: String) -> AppError {
        guard case .brewFailed(_, let stderr) = error else { return error }
        guard isPinnedUpgradeFailure(stderr) else { return error }
        return .unknown("Package '\(packageName)' is pinned. Run 'brew unpin \(packageName)' and try again.")
    }

    private func isPinnedUpgradeFailure(_ stderr: String) -> Bool {
        let message = stderr.lowercased()
        return message.contains("not upgrading") && message.contains("pinned")
    }

    /// Removes stale hidden state and invalid selections after a new package snapshot loads.
    private func reconcileLocalState(with packages: [BrewPackage]) {
        let packageIDs = Set(packages.map(\.id))
        hiddenPackageIDs.formIntersection(packageIDs)
        hiddenUpdatePackageIDs.formIntersection(packageIDs)

        let visibleUpdateIDs = Set(packages.filter { hasVisibleUpdate($0) }.map(\.id))
        selectedPackageIDs.formIntersection(visibleUpdateIDs)
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

            reconcileLocalState(with: cached.packages)
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
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedQuery.isEmpty else {
            activeSearchRequestID += 1
            searchState = .idle
            searchResults = []
            return
        }

        activeSearchRequestID += 1
        let requestID = activeSearchRequestID

        logger.info("Searching for packages: \(normalizedQuery)")
        searchState = .searching(query: normalizedQuery)

        do {
            let installedTypesByName = Dictionary(
                grouping: packages,
                by: { $0.name }
            ).mapValues { Set($0.map(\.type)) }

            let typedMatches: [(name: String, type: PackageType)]
            if let filter = searchTypeFilter {
                let names = try await client.searchPackages(normalizedQuery, type: filter, debugMode: debugMode)
                typedMatches = names.map { (name: $0, type: filter) }
            } else {
                let formulaNames = try await client.searchPackages(normalizedQuery, type: .formula, debugMode: debugMode)
                let caskNames = try await client.searchPackages(normalizedQuery, type: .cask, debugMode: debugMode)

                var deduplicated: [(name: String, type: PackageType)] = []
                var seenKeys = Set<String>()

                for name in formulaNames {
                    let key = "\(PackageType.formula.rawValue):\(name)"
                    if seenKeys.insert(key).inserted {
                        deduplicated.append((name: name, type: .formula))
                    }
                }

                for name in caskNames {
                    let key = "\(PackageType.cask.rawValue):\(name)"
                    if seenKeys.insert(key).inserted {
                        deduplicated.append((name: name, type: .cask))
                    }
                }

                typedMatches = deduplicated
            }

            guard requestID == activeSearchRequestID else {
                logger.debug("Ignoring stale search results for query: \(normalizedQuery)")
                return
            }

            let hasMore = typedMatches.count > searchPageSize
            let pageMatches = Array(typedMatches.prefix(searchPageSize))

            searchResults = pageMatches.map { match in
                let installedTypes = installedTypesByName[match.name] ?? []
                return SearchResult(
                    name: match.name,
                    type: match.type,
                    isInstalled: installedTypes.contains(match.type)
                )
            }

            searchState = .loaded(query: normalizedQuery, results: searchResults, hasMore: hasMore)
            logger.info("Found \(typedMatches.count) packages (\(self.searchResults.count) shown)")
            logHistory(
                operation: .search,
                packageName: normalizedQuery,
                details: "Found \(typedMatches.count) results",
                success: true
            )

        } catch let error as AppError {
            guard requestID == activeSearchRequestID else {
                logger.debug("Ignoring stale search error for query: \(normalizedQuery)")
                return
            }
            if case .cancelled = error {
                logger.debug("Search cancelled")
                searchState = .idle
                return
            }
            searchState = .error(error)
            logger.error("Search failed: \(error.localizedDescription)")
            logHistory(operation: .search, packageName: normalizedQuery, details: error.localizedDescription, success: false)
        } catch {
            guard requestID == activeSearchRequestID else {
                logger.debug("Ignoring stale search failure for query: \(normalizedQuery)")
                return
            }
            let appError = AppError.brewFailed(exitCode: -1, stderr: error.localizedDescription)
            searchState = .error(appError)
            logger.error("Search failed: \(error.localizedDescription)")
            logHistory(operation: .search, packageName: normalizedQuery, details: error.localizedDescription, success: false)
        }
    }

    /// Clears search results and resets to idle state.
    func clearSearch(resetFilter: Bool = false) {
        activeSearchRequestID += 1
        searchState = .idle
        searchResults = []
        if resetFilter {
            searchTypeFilter = nil
        }
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
            let info = try await client.getPackageInfo(result.name, type: result.type, debugMode: debugMode)
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
            logHistory(operation: .install, packageName: result.name, success: true)

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
            logHistory(operation: .install, packageName: result.name, details: error.localizedDescription, success: false)
        } catch {
            let appError = AppError.brewFailed(exitCode: -1, stderr: error.localizedDescription)
            installOperations[result.name] = PackageOperation(
                status: .failed,
                error: appError,
                diagnostics: "Failed to install \(result.name): \(error.localizedDescription)"
            )
            logHistory(operation: .install, packageName: result.name, details: error.localizedDescription, success: false)
        }
    }

    /// Clears the installation operation status for a package.
    ///
    /// - Parameter packageName: The name of the package to clear the operation for.
    func clearInstallOperation(for packageName: String) {
        installOperations.removeValue(forKey: packageName)
    }

    // MARK: - Update Checking

    /// Checks for application updates.
    ///
    /// Fetches the latest release from GitHub and compares with the current version.
    /// Updates `updateCheckResult` with the result.
    ///
    /// - Parameters:
    ///   - settings: App settings containing update preferences
    ///   - manual: Whether this is a manual check (always shows result)
    func checkForUpdates(settings: AppSettings, manual: Bool = false) async {
        guard !isCheckingForUpdates else {
            logger.info("Update check already in progress")
            return
        }

        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }

        // Get current version from bundle
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            logger.error("Could not read current version from bundle")
            updateCheckResult = .error(.updateCheckFailed(reason: "Could not read app version"))
            return
        }

        logger.info("Checking for updates (current version: \(currentVersion))...")

        let result = await updateChecker.checkForUpdates(
            currentVersion: currentVersion,
            skippedVersion: settings.skippedVersion
        )

        updateCheckResult = result
        settings.lastUpdateCheck = Date()

        // Log result
        switch result {
        case .upToDate:
            logger.info("App is up to date")
        case .updateAvailable(let release):
            logger.info("Update available: \(release.version)")
        case .error(let error):
            logger.error("Update check failed: \(error.localizedDescription)")
        }
    }
}
