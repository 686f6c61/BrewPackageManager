# Architecture

## High-level Layers

1. UI Layer (`MenuBar/Reboot`, feature stores, status-item chrome)
  - SwiftUI shell and screen composition.
  - No shell execution directly from views.

2. State Layer (`PackagesStore`, feature stores)
  - Main-actor observable state for UI.
  - Coordinates operations, progress, errors, and navigation data.

3. Domain + Client Layer (`Brew`, `Services`, `Cleanup`, `Dependencies`, `Updates`)
  - Actor-based clients perform command and decode work.
  - Store-facing APIs return strongly typed domain models.

4. Shell Execution Layer (`Shell`)
  - `CommandExecutor` runs subprocesses with timeout, cancellation, and output capture limits.
  - Central point for command diagnostics persistence.

5. Persistence Layer (`PackagesDiskCache`, `HistoryDatabase`, `UserDefaults`)
  - Cache for package snapshots.
  - User settings and operation history.

## Concurrency Model

- UI and stores run on `@MainActor`.
- Command clients are actors to serialize command execution and avoid race conditions.
- Long-running work is async and cancellation-aware.
- Shell pipe reading is asynchronous and lock-protected to avoid deadlocks.

## Error Model

- Domain errors use `AppError`.
- Blocking errors move store state to `.error`.
- Non-blocking errors are surfaced via `nonFatalError` and keep cached data visible.
- Operation-level failures are tracked by `PackageOperation` and feature-specific stores.

## Startup Flow

1. `BrewPackageManagerApp` initializes `PackagesStore` and `AppSettings`.
2. `BrewPackageManagerAppDelegate` installs `MenuBarStatusController`.
3. `MenuBarStatusController` configures the status item, popover, and optional management window.
4. The popover/window render `RebootMenuRootView`.
5. The store restores cached package snapshot (if available).
6. The store refreshes from Homebrew and merges metadata.
7. Optional update check runs if interval policy allows.

## Active UI

The runtime shell is:
- `/Users/00b/Desktop/homebrew/BrewPackageManager/BrewPackageManager/BrewPackageManager/MenuBar/Reboot/RebootMenuRootView.swift`

The older SwiftUI menu stack has already been removed from the repository as part of the 2.0 cleanup pass. What remains now is to break the reboot shell into smaller screen files and continue decomposing large state surfaces.

## Current Hotspots

- `PackagesStore` still owns too many responsibilities.
- `RebootMenuRootView` is currently too large for the long-term design goals.
- Services/dependencies/history/statistics are functionally available, but still need further decomposition and dedicated view files.

## Design Principles

- Keep CLI behavior explicit: no hidden retries that change semantics.
- Keep UI resilient: avoid dead states after command failures.
- Keep internals composable: thin views, rich stores/clients, typed models.
- Keep advanced tooling auditable with repeatable local and Docker-based checks.
