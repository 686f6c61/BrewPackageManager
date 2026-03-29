# Module Reference

## Core App Entry

- `BrewPackageManager/BrewPackageManager/BrewPackageManagerApp.swift`
  - App bootstrap and dependency injection.
- `BrewPackageManager/BrewPackageManager/MenuBar/MenuBarStatusController.swift`
  - Status item, popover, quick-actions menu, and management window.

## Brew Module (`BrewPackageManager/BrewPackageManager/Brew`)

- `BrewPackagesClient.swift`
  - Main Homebrew operations actor (list/info/outdated/pinned/search/install/upgrade/uninstall).
- `BrewPackagesClientProtocol.swift`
  - Contract for real client and test mocks.
- `BrewPackagesArgumentsBuilder.swift`
  - Homebrew argument construction in one place.
- `BrewResponseTypes.swift`
  - Codable response models for `brew info` and `brew outdated`.
- `BrewPackage.swift`, `BrewPackageInfo.swift`, `PackageType.swift`, `SearchResult.swift`
  - Domain models.
- `BrewLocator.swift`, `BrewLocatorError.swift`
  - `brew` binary detection and locator errors.

## Packages Module (`BrewPackageManager/BrewPackageManager/Packages`)

- `PackagesStore.swift`
  - Main app state and orchestration. Current 2.0 hotspot for decomposition.
- `PackagesState.swift`, `SearchState.swift`
  - State machines for package list and search.
- `PackageOperation.swift`, `PackageOperationStatus.swift`
  - Operation tracking for per-package tasks.
- `PackagesDiskCache.swift`
  - Snapshot cache for fast startup.
- `AppError.swift`
  - Shared domain error surface.

## Active 2.0 UI (`BrewPackageManager/BrewPackageManager/MenuBar/Reboot`)

- `RebootMenuRootView.swift`
  - Active 2.0 SwiftUI shell for overview, search, tools, settings, and detail screens.
- `RebootTheme.swift`
  - Shared 2.0 visual tokens and reusable controls.

## Shell Module (`BrewPackageManager/BrewPackageManager/Shell`)

- `CommandExecutor.swift`
  - Process execution, timeout, cancellation, bounded capture, diagnostics.
- `CommandResult.swift`
  - Command result and diagnostics payload models.
- `CommandExecutorError.swift`
  - Executor-specific errors.

## Settings Module (`BrewPackageManager/BrewPackageManager/Settings`)

- `AppSettings.swift`
  - UserDefaults-backed settings and launch-at-login integration.
  - The active settings screen currently lives inside the 2.0 reboot shell.

## Updates Module (`BrewPackageManager/BrewPackageManager/Updates`)

- `GitHubClient.swift`
  - Fetch latest release metadata.
- `UpdateChecker.swift`
  - Compare versions and determine update state.
- `ReleaseInfo.swift`, `UpdateCheckResult.swift`, `VersionComparator.swift`
  - Update models and version semantics.

## Services Module (`BrewPackageManager/BrewPackageManager/Services`)

- `ServicesClient.swift`
  - `brew services` command integration.
- `ServicesStore.swift`
  - Service operation state handling.
- `BrewService.swift`
  - Service model.

## Cleanup Module (`BrewPackageManager/BrewPackageManager/Cleanup`)

- `CleanupClient.swift`
  - Cleanup and cache command logic.
- `CleanupStore.swift`
  - Cleanup state and orchestration.
- `CleanupInfo.swift`
  - Cleanup data model.

## Dependencies Module (`BrewPackageManager/BrewPackageManager/Dependencies`)

- `DependenciesClient.swift`
  - Dependency graph construction from Homebrew data.
- `DependenciesStore.swift`
  - Dependencies state.
- `DependencyInfo.swift`
  - Dependency model.

## History Module (`BrewPackageManager/BrewPackageManager/History`)

- `HistoryDatabase.swift`
  - Persistent storage for operation history.
- `HistoryStore.swift`
  - History query and aggregation logic.
- `HistoryEntry.swift`
  - History model and operation taxonomy.

## Shared UI and Utilities

- `BrewPackageManager/BrewPackageManager/Utilities/AppKitBridge.swift`
  - AppKit interoperability helpers.
