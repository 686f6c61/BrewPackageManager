//
//  BrewPackageManagerTests.swift
//  BrewPackageManagerTests
//
//  Created by R on 4/1/26.
//

import Foundation
import Testing
@testable import BrewPackageManager

struct BrewPackageManagerTests {

    @Test("AppSettings keeps auto-refresh disabled when set to 0")
    @MainActor
    func appSettingsPreservesZeroInterval() async throws {
        let suiteName = "BrewPackageManagerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let settings = AppSettings(defaults: defaults)
        settings.autoRefreshInterval = 0

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.autoRefreshInterval == 0)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("Package IDs remain unique across formula and cask types")
    func packageIDIncludesType() {
        let formula = BrewPackage(
            name: "example",
            fullName: "homebrew/core/example",
            desc: nil,
            homepage: nil,
            type: .formula,
            installedVersion: "1.0.0",
            currentVersion: "1.0.0",
            isOutdated: false,
            pinnedVersion: nil,
            tap: "homebrew/core"
        )

        let cask = BrewPackage(
            name: "example",
            fullName: "homebrew/cask/example",
            desc: nil,
            homepage: nil,
            type: .cask,
            installedVersion: "1.0.0",
            currentVersion: "1.0.0",
            isOutdated: false,
            pinnedVersion: nil,
            tap: "homebrew/cask"
        )

        #expect(formula.id != cask.id)
        #expect(formula.id.hasPrefix("formula:"))
        #expect(cask.id.hasPrefix("cask:"))
    }

    @Test("Command diagnostics status summary reflects timeout/cancel/exit")
    func commandDiagnosticsStatusSummary() {
        let timedOut = CommandExecutionDiagnostics(
            timestamp: Date(),
            executablePath: "/usr/bin/brew",
            arguments: ["upgrade"],
            exitCode: 15,
            wasCancelled: false,
            timedOut: true,
            durationSeconds: 12.3,
            stdoutBytesTotal: 100,
            stderrBytesTotal: 10,
            stdoutBytesCaptured: 100,
            stderrBytesCaptured: 10,
            stdoutTruncated: false,
            stderrTruncated: false,
            captureLimitBytes: 1024,
            launchError: nil
        )
        #expect(timedOut.statusSummary == "Timed out")

        let cancelled = CommandExecutionDiagnostics(
            timestamp: Date(),
            executablePath: "/usr/bin/brew",
            arguments: ["upgrade"],
            exitCode: nil,
            wasCancelled: true,
            timedOut: false,
            durationSeconds: 1.0,
            stdoutBytesTotal: 0,
            stderrBytesTotal: 0,
            stdoutBytesCaptured: 0,
            stderrBytesCaptured: 0,
            stdoutTruncated: false,
            stderrTruncated: false,
            captureLimitBytes: nil,
            launchError: nil
        )
        #expect(cancelled.statusSummary == "Cancelled")

        let failed = CommandExecutionDiagnostics(
            timestamp: Date(),
            executablePath: "/usr/bin/brew",
            arguments: ["upgrade"],
            exitCode: 1,
            wasCancelled: false,
            timedOut: false,
            durationSeconds: 0.5,
            stdoutBytesTotal: 0,
            stderrBytesTotal: 4,
            stdoutBytesCaptured: 0,
            stderrBytesCaptured: 4,
            stdoutTruncated: false,
            stderrTruncated: false,
            captureLimitBytes: nil,
            launchError: nil
        )
        #expect(failed.statusSummary == "Exit code 1")
    }

    @Test("Upgrade failure resets updating state and surfaces non-fatal error")
    func upgradeFailureResetsState() async {
        let package = BrewPackage(
            name: "tree",
            fullName: "homebrew/core/tree",
            desc: nil,
            homepage: nil,
            type: .formula,
            installedVersion: "2.2.1",
            currentVersion: "2.3.1",
            isOutdated: true,
            pinnedVersion: nil,
            tap: "homebrew/core"
        )

        let store = await MainActor.run { PackagesStore(client: MockUpgradeFailingClient()) }
        await MainActor.run {
            store.state = .loaded([package])
            store.selectedPackageIDs = [package.id]
        }

        await MainActor.run {
            store.nonFatalError = nil
        }

        let upgradeTask = await MainActor.run {
            Task {
                await store.upgradeSelected(debugMode: false)
            }
        }
        await upgradeTask.value

        await MainActor.run {
            #expect(store.isUpgradingSelected == false)
            #expect(store.upgradeProgress == nil)
            #expect(store.nonFatalError != nil)
        }
    }

    @Test("Select all outdated skips pinned packages")
    func selectAllOutdatedSkipsPinned() async {
        let pinned = BrewPackage(
            name: "tree",
            fullName: "homebrew/core/tree",
            desc: nil,
            homepage: nil,
            type: .formula,
            installedVersion: "2.2.1",
            currentVersion: "2.3.1",
            isOutdated: true,
            pinnedVersion: "2.2.1",
            tap: "homebrew/core"
        )
        let updatable = BrewPackage(
            name: "wget",
            fullName: "homebrew/core/wget",
            desc: nil,
            homepage: nil,
            type: .formula,
            installedVersion: "1.0.0",
            currentVersion: "1.1.0",
            isOutdated: true,
            pinnedVersion: nil,
            tap: "homebrew/core"
        )

        let store = await MainActor.run { PackagesStore(client: MockTrackingClient()) }
        await MainActor.run {
            store.state = .loaded([pinned, updatable])
            store.selectAllOutdated()
        }

        await MainActor.run {
            #expect(store.selectedPackageIDs.contains(updatable.id))
            #expect(store.selectedPackageIDs.contains(pinned.id) == false)
        }
    }

    @Test("Visible outdated packages exclude pinned and hidden entries")
    func visibleOutdatedPackagesExcludePinnedAndHiddenEntries() async {
        let pinned = BrewPackage(
            name: "tree",
            fullName: "homebrew/core/tree",
            desc: nil,
            homepage: nil,
            type: .formula,
            installedVersion: "2.2.1",
            currentVersion: "2.3.2",
            isOutdated: true,
            pinnedVersion: "2.2.1",
            tap: "homebrew/core"
        )
        let hiddenUpdate = BrewPackage(
            name: "wget",
            fullName: "homebrew/core/wget",
            desc: nil,
            homepage: nil,
            type: .formula,
            installedVersion: "1.0.0",
            currentVersion: "1.1.0",
            isOutdated: true,
            pinnedVersion: nil,
            tap: "homebrew/core"
        )
        let hiddenPackage = BrewPackage(
            name: "htop",
            fullName: "homebrew/core/htop",
            desc: nil,
            homepage: nil,
            type: .formula,
            installedVersion: "3.3.0",
            currentVersion: nil,
            isOutdated: false,
            pinnedVersion: nil,
            tap: "homebrew/core"
        )
        let visibleUpdate = BrewPackage(
            name: "git",
            fullName: "homebrew/core/git",
            desc: nil,
            homepage: nil,
            type: .formula,
            installedVersion: "2.49.0",
            currentVersion: "2.49.1",
            isOutdated: true,
            pinnedVersion: nil,
            tap: "homebrew/core"
        )

        let store = await MainActor.run { PackagesStore(client: MockTrackingClient()) }
        await MainActor.run {
            store.state = .loaded([pinned, hiddenUpdate, hiddenPackage, visibleUpdate])
            store.hideUpdate(for: hiddenUpdate)
            store.hidePackage(hiddenPackage)
        }

        await MainActor.run {
            #expect(store.visiblePackages.map(\.id) == [pinned.id, hiddenUpdate.id, visibleUpdate.id])
            #expect(store.visibleOutdatedPackages.map(\.id) == [visibleUpdate.id])
            #expect(store.visibleOutdatedCount == 1)
            #expect(store.hiddenItems.count == 2)
        }
    }

    @Test("Select all outdated skips hidden updates")
    func selectAllOutdatedSkipsHiddenUpdates() async {
        let hiddenUpdate = BrewPackage(
            name: "python",
            fullName: "homebrew/core/python",
            desc: nil,
            homepage: nil,
            type: .formula,
            installedVersion: "3.12.2",
            currentVersion: "3.12.3",
            isOutdated: true,
            pinnedVersion: nil,
            tap: "homebrew/core"
        )
        let visibleUpdate = BrewPackage(
            name: "git",
            fullName: "homebrew/core/git",
            desc: nil,
            homepage: nil,
            type: .formula,
            installedVersion: "2.49.0",
            currentVersion: "2.49.1",
            isOutdated: true,
            pinnedVersion: nil,
            tap: "homebrew/core"
        )

        let store = await MainActor.run { PackagesStore(client: MockTrackingClient()) }
        await MainActor.run {
            store.state = .loaded([hiddenUpdate, visibleUpdate])
            store.hideUpdate(for: hiddenUpdate)
            store.selectAllOutdated()
        }

        await MainActor.run {
            #expect(store.selectedPackageIDs == Set([visibleUpdate.id]))
        }
    }

    @Test("Hidden visibility preferences persist across store instances")
    @MainActor
    func hiddenVisibilityPreferencesPersistAcrossStoreInstances() async throws {
        let suiteName = "BrewPackageManagerTests.Hidden.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let package = BrewPackage(
            name: "tree",
            fullName: "homebrew/core/tree",
            desc: nil,
            homepage: nil,
            type: .formula,
            installedVersion: "2.2.1",
            currentVersion: "2.3.2",
            isOutdated: true,
            pinnedVersion: nil,
            tap: "homebrew/core"
        )

        let firstStore = PackagesStore(client: MockTrackingClient(), defaults: defaults)
        firstStore.state = .loaded([package])
        firstStore.hidePackage(package)
        firstStore.hideUpdate(for: package)

        let reloadedStore = PackagesStore(client: MockTrackingClient(), defaults: defaults)
        reloadedStore.state = .loaded([package])

        #expect(reloadedStore.isPackageHidden(package))
        #expect(reloadedStore.isUpdateHidden(package) == false)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("Pinned-only selection does not start upgrade and reports guidance")
    func pinnedOnlySelectionShowsGuidance() async {
        let pinned = BrewPackage(
            name: "tree",
            fullName: "homebrew/core/tree",
            desc: nil,
            homepage: nil,
            type: .formula,
            installedVersion: "2.2.1",
            currentVersion: "2.3.1",
            isOutdated: true,
            pinnedVersion: "2.2.1",
            tap: "homebrew/core"
        )

        let client = MockTrackingClient()
        let store = await MainActor.run { PackagesStore(client: client) }
        await MainActor.run {
            store.state = .loaded([pinned])
            store.selectedPackageIDs = [pinned.id]
            store.nonFatalError = nil
        }

        let upgradeTask = await MainActor.run {
            Task {
                await store.upgradeSelected(debugMode: false)
            }
        }
        await upgradeTask.value

        let upgradeCallCount = await client.upgradeCallCount()

        await MainActor.run {
            #expect(store.isUpgradingSelected == false)
            #expect(store.upgradeProgress == nil)
            #expect(store.nonFatalError != nil)
        }
        #expect(upgradeCallCount == 0)
    }

    @Test("Upgrade uses pinned list even when package metadata is stale")
    func upgradeSkipsPinnedFromPinnedList() async {
        let package = BrewPackage(
            name: "tree",
            fullName: "homebrew/core/tree",
            desc: nil,
            homepage: nil,
            type: .formula,
            installedVersion: "2.2.1",
            currentVersion: "2.3.1",
            isOutdated: true,
            pinnedVersion: nil,
            tap: "homebrew/core"
        )

        let client = MockTrackingClient(pinnedPackages: ["tree"])
        let store = await MainActor.run { PackagesStore(client: client) }
        await MainActor.run {
            store.state = .loaded([package])
            store.selectedPackageIDs = [package.id]
            store.nonFatalError = nil
        }

        let upgradeTask = await MainActor.run {
            Task {
                await store.upgradeSelected(debugMode: false)
            }
        }
        await upgradeTask.value

        let upgradeCallCount = await client.upgradeCallCount()

        await MainActor.run {
            #expect(store.isUpgradingSelected == false)
            #expect(store.upgradeProgress == nil)
            #expect(store.nonFatalError != nil)
            if let error = store.nonFatalError {
                #expect(error.localizedDescription.lowercased().contains("pinned"))
            }
        }
        #expect(upgradeCallCount == 0)
    }

    @Test("Outdated cask decoding supports array installed_versions")
    func outdatedCaskDecodesInstalledVersionsArray() throws {
        let json = """
        {
          "formulae": [],
          "casks": [
            {
              "name": "codex",
              "installed_versions": ["0.101.0"],
              "current_version": "0.104.0"
            }
          ]
        }
        """

        let response = try BrewOutdatedResponse.decode(from: json)
        #expect(response.casks.count == 1)
        #expect(response.casks[0].installedVersions == ["0.101.0"])
        #expect(response.casks[0].currentVersion == "0.104.0")
    }

    @Test("Outdated cask decoding supports legacy string installed_versions")
    func outdatedCaskDecodesInstalledVersionsString() throws {
        let json = """
        {
          "formulae": [],
          "casks": [
            {
              "name": "legacy-cask",
              "installed_versions": "1.2.3",
              "current_version": ["1.2.4"]
            }
          ]
        }
        """

        let response = try BrewOutdatedResponse.decode(from: json)
        #expect(response.casks.count == 1)
        #expect(response.casks[0].installedVersions == ["1.2.3"])
        #expect(response.casks[0].currentVersion == "1.2.4")
    }

    @Test("Cache clearing removes directory contents and keeps root directory")
    func clearDirectoryContentsKeepsCacheRoot() throws {
        let fileManager = FileManager.default
        let cacheRoot = fileManager.temporaryDirectory
            .appendingPathComponent("BrewPackageManagerTests-\(UUID().uuidString)", isDirectory: true)
        let nestedDirectory = cacheRoot.appendingPathComponent("nested", isDirectory: true)
        let topLevelFile = cacheRoot.appendingPathComponent("archive.tar.gz")
        let hiddenFile = cacheRoot.appendingPathComponent(".hidden")
        let nestedFile = nestedDirectory.appendingPathComponent("artifact.txt")

        try fileManager.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        try Data("top".utf8).write(to: topLevelFile)
        try Data("hidden".utf8).write(to: hiddenFile)
        try Data("nested".utf8).write(to: nestedFile)
        defer { try? fileManager.removeItem(at: cacheRoot) }

        let removedEntries = try CleanupClient.clearDirectoryContents(at: cacheRoot, fileManager: fileManager)
        #expect(removedEntries == 3)

        var isDirectory: ObjCBool = false
        #expect(fileManager.fileExists(atPath: cacheRoot.path(), isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)

        let remainingItems = try fileManager.contentsOfDirectory(
            at: cacheRoot,
            includingPropertiesForKeys: nil,
            options: []
        )
        #expect(remainingItems.isEmpty)
    }

    @Test("Cleanup dry-run parsing counts only old package versions")
    func cleanupDryRunParsingCountsOnlyPackageVersions() {
        let output = """
        Warning: Skipping mongodb/brew/mongodb-community: most recent version 8.2.6 not installed
        Would remove: /opt/homebrew/Cellar/node/25.8.0 (1,927 files, 77.9MB)
        Would remove: /opt/homebrew/Caskroom/docker/4.42.0 (221 files, 1.1GB)
        Would remove: /Users/test/Library/Caches/Homebrew/node--25.8.0 (18.4MB)
        Would remove: /Users/test/Library/Caches/Homebrew/node_bottle_manifest--25.8.0 (27.7KB)
        """

        let info = CleanupInfo.parseFromOutput(stdout: output)
        #expect(info.oldVersions == 2)
    }

    @Test("Cleanup explanations separate cache from old versions")
    func cleanupExplanationsDifferentiateActions() {
        let info = CleanupInfo(cacheSize: 2_000_000_000, cachedFiles: 100, oldVersions: 12)

        #expect(info.cacheExplanation.localizedCaseInsensitiveContains("download"))
        #expect(info.oldVersionsExplanation.localizedCaseInsensitiveContains("does not uninstall"))
        #expect(info.clearCacheActionDescription.localizedCaseInsensitiveContains("old package versions remain"))
        #expect(info.cleanOldVersionsActionDescription.localizedCaseInsensitiveContains("current installed version stays"))
    }

    @Test("Old versions remaining message is explicit after cache clear")
    func oldVersionsRemainingMessageIsExplicit() {
        #expect(CleanupInfo(cacheSize: 0, cachedFiles: 0, oldVersions: 0).oldVersionsRemainingMessage == "No old package versions remain.")
        #expect(CleanupInfo(cacheSize: 0, cachedFiles: 0, oldVersions: 1).oldVersionsRemainingMessage == "1 old package version still remains.")
        #expect(CleanupInfo(cacheSize: 0, cachedFiles: 0, oldVersions: 64).oldVersionsRemainingMessage == "64 old package versions still remain.")
    }

    @Test("Clearing search preserves filter unless explicitly reset")
    @MainActor
    func clearSearchPreservesFilterUnlessExplicitlyReset() {
        let store = PackagesStore(client: MockTrackingClient())
        store.searchTypeFilter = .cask

        store.clearSearch()
        #expect(store.searchTypeFilter == .cask)

        store.clearSearch(resetFilter: true)
        #expect(store.searchTypeFilter == nil)
    }

    @Test("Latest search response wins over stale in-flight results")
    func latestSearchResponseWins() async {
        let store = await MainActor.run { PackagesStore(client: MockSearchRaceClient()) }
        await MainActor.run {
            store.searchTypeFilter = .formula
        }

        let firstSearch = await MainActor.run {
            Task {
                await store.search(query: "py", debugMode: false)
            }
        }

        let secondSearch = await MainActor.run {
            Task {
                await store.search(query: "python", debugMode: false)
            }
        }

        await secondSearch.value
        await firstSearch.value

        await MainActor.run {
            guard case .loaded(let query, let results, let hasMore) = store.searchState else {
                Issue.record("Expected loaded search state")
                return
            }

            #expect(query == "python")
            #expect(hasMore == false)
            #expect(results.map(\.name) == ["python"])
        }
    }

}

actor MockUpgradeFailingClient: BrewPackagesClientProtocol {
    func listInstalledPackages(debugMode: Bool) async throws -> [BrewPackage] { [] }
    func listOutdatedPackages(debugMode: Bool) async throws -> [String] { [] }
    func listPinnedPackages(debugMode: Bool) async throws -> Set<String> { [] }
    func getPackageInfo(_ packageName: String, type: PackageType?, debugMode: Bool) async throws -> BrewPackageInfo {
        throw AppError.unknown("not used")
    }
    func upgradePackage(_ packageName: String, type: PackageType, debugMode: Bool) async throws {
        throw AppError.brewFailed(exitCode: 1, stderr: "mock failure")
    }
    func upgradeAllPackages(debugMode: Bool) async throws {}
    func uninstallPackage(_ packageName: String, type: PackageType, debugMode: Bool) async throws {}
    func searchPackages(_ query: String, type: PackageType?, debugMode: Bool) async throws -> [String] { [] }
    func installPackage(_ packageName: String, type: PackageType, debugMode: Bool) async throws {}
}

actor MockTrackingClient: BrewPackagesClientProtocol {
    private var upgradeCalls = 0
    private let pinnedPackages: Set<String>

    init(pinnedPackages: Set<String> = []) {
        self.pinnedPackages = pinnedPackages
    }

    func listInstalledPackages(debugMode: Bool) async throws -> [BrewPackage] { [] }
    func listOutdatedPackages(debugMode: Bool) async throws -> [String] { [] }
    func listPinnedPackages(debugMode: Bool) async throws -> Set<String> { pinnedPackages }
    func getPackageInfo(_ packageName: String, type: PackageType?, debugMode: Bool) async throws -> BrewPackageInfo {
        throw AppError.unknown("not used")
    }
    func upgradePackage(_ packageName: String, type: PackageType, debugMode: Bool) async throws {
        upgradeCalls += 1
    }
    func upgradeAllPackages(debugMode: Bool) async throws {}
    func uninstallPackage(_ packageName: String, type: PackageType, debugMode: Bool) async throws {}
    func searchPackages(_ query: String, type: PackageType?, debugMode: Bool) async throws -> [String] { [] }
    func installPackage(_ packageName: String, type: PackageType, debugMode: Bool) async throws {}

    func upgradeCallCount() -> Int {
        upgradeCalls
    }
}

actor MockSearchRaceClient: BrewPackagesClientProtocol {
    func listInstalledPackages(debugMode: Bool) async throws -> [BrewPackage] { [] }
    func listOutdatedPackages(debugMode: Bool) async throws -> [String] { [] }
    func listPinnedPackages(debugMode: Bool) async throws -> Set<String> { [] }
    func getPackageInfo(_ packageName: String, type: PackageType?, debugMode: Bool) async throws -> BrewPackageInfo {
        throw AppError.unknown("not used")
    }
    func upgradePackage(_ packageName: String, type: PackageType, debugMode: Bool) async throws {}
    func upgradeAllPackages(debugMode: Bool) async throws {}
    func uninstallPackage(_ packageName: String, type: PackageType, debugMode: Bool) async throws {}
    func installPackage(_ packageName: String, type: PackageType, debugMode: Bool) async throws {}

    func searchPackages(_ query: String, type: PackageType?, debugMode: Bool) async throws -> [String] {
        if query == "py" {
            try? await Task.sleep(for: .milliseconds(150))
            return ["pyenv"]
        }

        if query == "python" {
            try? await Task.sleep(for: .milliseconds(20))
            return ["python"]
        }

        return []
    }
}
