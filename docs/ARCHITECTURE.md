# Architecture

## High-level Layers

1. UI Layer (`MenuBar`, `Settings`, feature views)
  - SwiftUI screens and route transitions.
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
- Operation-level failures are tracked by `PackageOperation`.

## Startup Flow

1. `BrewPackageManagerApp` initializes `PackagesStore` and `AppSettings`.
2. `MenuBarRootView` appears and calls `configureAutoRefresh`.
3. Store restores cached package snapshot (if available).
4. Store refreshes from Homebrew and merges metadata.
5. Optional update check runs if interval policy allows.

## Design Principles

- Keep CLI behavior explicit: no hidden retries that change semantics.
- Keep UI resilient: avoid dead states after command failures.
- Keep internals composable: thin views, rich stores/clients, typed models.
