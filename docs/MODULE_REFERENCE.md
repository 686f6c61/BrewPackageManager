# Module Reference

## Core App Entry

- `BrewPackageManager/BrewPackageManager/BrewPackageManagerApp.swift`
  - App bootstrap, menu bar icon state, dependency injection for store/settings.

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
  - Main app state and orchestration.
- `PackagesState.swift`, `SearchState.swift`
  - State machines for package list and search.
- `PackageOperation.swift`, `PackageOperationStatus.swift`
  - Operation tracking for per-package tasks.
- `PackagesDiskCache.swift`
  - Snapshot cache for fast startup.
- `AppError.swift`
  - Shared domain error surface.

## Menu UI (`BrewPackageManager/BrewPackageManager/MenuBar`)

- `MenuBarRootView.swift`
  - Route switching and feature view navigation.
- `MainMenuContentView.swift`
  - Top-level menu composition.
- `PackagesSectionView.swift`, `PackageMenuItemView.swift`, `UpdateActionsSectionView.swift`
  - Core package interaction.
- `SearchView.swift`, `SearchResultRow.swift`
  - Search UI and install flows.
- `PackageInfoView.swift`
  - Detailed package metadata presentation.
- `HelpView.swift`, `ErrorView.swift`, `EmptyStateView.swift`
  - Auxiliary views.
- `MenuBarRoute.swift`, `MenuBarHeaderView.swift`, `MenuRowButton.swift`
  - Routing and shared menu components.

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
- `SettingsView.swift`
  - Preferences UI and diagnostics/export controls.

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
- `ServicesView.swift`
  - Service UI.
- `BrewService.swift`
  - Service model.

## Cleanup Module (`BrewPackageManager/BrewPackageManager/Cleanup`)

- `CleanupClient.swift`
  - Cleanup and cache command logic.
- `CleanupStore.swift`
  - Cleanup state and orchestration.
- `CleanupView.swift`
  - Cleanup UI.
- `CleanupInfo.swift`
  - Cleanup data model.

## Dependencies Module (`BrewPackageManager/BrewPackageManager/Dependencies`)

- `DependenciesClient.swift`
  - Dependency graph construction from Homebrew data.
- `DependenciesStore.swift`
  - Dependencies state.
- `DependenciesView.swift`
  - Dependencies UI.
- `DependencyInfo.swift`
  - Dependency model.

## History Module (`BrewPackageManager/BrewPackageManager/History`)

- `HistoryDatabase.swift`
  - Persistent storage for operation history.
- `HistoryStore.swift`
  - History query and aggregation logic.
- `HistoryView.swift`, `StatisticsView.swift`
  - History and stats UI.
- `HistoryEntry.swift`
  - History model and operation taxonomy.

## Shared UI and Utilities

- `BrewPackageManager/BrewPackageManager/Components`
  - Reusable section/header primitives.
- `BrewPackageManager/BrewPackageManager/Design`
  - Styling and visual modifiers.
- `BrewPackageManager/BrewPackageManager/Utilities/AppKitBridge.swift`
  - AppKit interoperability helpers.
