# Runtime Workflows

## 1) App Launch and First Refresh

1. App starts and creates `PackagesStore` + `AppSettings`.
2. Menu root configures auto-refresh loop.
3. Store restores cached packages (if present).
4. Store requests:
  - Installed packages (`brew info --json=v2 --installed`).
  - Outdated list (`brew outdated --json=v2`).
  - Pinned formulae (`brew list --pinned`).
5. Store merges metadata and updates UI state.

## 2) Selective Bulk Upgrade

1. User selects outdated rows.
2. Store resolves selected packages.
3. Store loads current pinned names from Homebrew.
4. Pinned packages are marked failed with guidance (`brew unpin <name>`).
5. Non-pinned packages upgrade sequentially.
6. Progress and per-package operation status update in real time.
7. Store resets progress flags and triggers background refresh.

## 3) Pinned Formula Handling

- Pinned formulae are recognized from real Homebrew state, not only stale cached metadata.
- UI shows pinned indicator instead of selectable checkbox.
- Bulk action "Select All Outdated" excludes pinned formulae.
- If Homebrew returns pinned failure text, error is remapped to actionable guidance.

## 4) Search and Install

1. User searches package name.
2. Store executes formula and cask searches.
3. Results are typed and deduplicated.
4. Install action resolves package type and runs install command.
5. Store updates install operation state and refreshes package list on success.

## 5) Services

1. Services view requests list from `brew services list`.
2. User starts/stops/restarts selected service.
3. Store updates operation status and refreshes service state.
4. Operation is logged to history.

## 6) Cleanup and Cache

1. Cleanup store loads dry-run metrics and cache path.
2. User chooses cleanup mode.
3. Client runs cleanup command with bounded capture.
4. Store refreshes cleanup metrics and logs outcome.

## 7) Dependencies

1. Dependencies client fetches installed package info in bulk.
2. Dependency graph and reverse edges are built in memory.
3. View supports filtering and export.

## 8) History and Statistics

1. Stores log operation events through `HistoryStore`.
2. History database persists JSON payload in UserDefaults.
3. Statistics view computes operation-level aggregates from stored entries.

## 9) Update Check

1. Update checker evaluates timing policy.
2. GitHub client fetches latest release data.
3. Version comparator decides up-to-date vs update-available.
4. UI surfaces release details and user actions.

## 10) Command Diagnostics

- Last command diagnostics are persisted after each shell command run.
- Diagnostics include timeout/cancel status and output truncation metadata.
- Settings view exposes diagnostics for troubleshooting.
