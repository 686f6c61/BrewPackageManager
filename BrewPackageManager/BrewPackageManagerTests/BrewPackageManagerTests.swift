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
