# Testing Strategy

## Goals

- Keep command execution reliable under real Homebrew output.
- Prevent UI dead states after command failures.
- Ensure package identity and selection logic remain correct across formula/cask.
- Keep release packaging reproducible.
- Make the 2.0 shell auditable with both Apple-native and Docker-based tooling.

## Automated Test Scope

Current emphasis:

- `18` unit tests in `BrewPackageManagerTests` for:
  - settings persistence
  - package identity and visibility rules
  - command diagnostics summaries
  - pinned-package selection/skip behavior
  - outdated JSON compatibility
  - cleanup messaging and parsing
  - search race handling
- `3` UI smoke tests in `BrewPackageManagerUITests` for launch/basic runtime sanity.

Run command:

```bash
xcodebuild \
  -project BrewPackageManager/BrewPackageManager.xcodeproj \
  -scheme BrewPackageManager \
  -destination 'platform=macOS' \
  -derivedDataPath .derived-audit-2 \
  test
```

## External Audit Lane

Run the Docker-based audit:

```bash
./scripts/audit-swift-in-docker.sh
```

It currently executes:
- `SwiftLint`
- `SwiftFormat --lint`
- `Semgrep`

The output is useful for release gating, but not yet clean enough to be a required pass for 2.0.

## Manual Smoke Checklist

1. Startup and refresh
  - App opens.
  - Overview renders.
  - No endless loading/updating state.

2. Upgrade flow
  - A non-pinned outdated package upgrades successfully.
  - A pinned formula is skipped with actionable guidance.

3. Search/install
  - Search returns typed results while typing.
  - Install updates package list and operation status.

4. Services
  - Start/stop/restart modifies status as expected.

5. Cleanup
  - Metrics load.
  - Cache clear acts immediately.
  - Old-version cleanup confirms before removal.

6. Tools
  - Dependencies/history/statistics render without layout breakage.
  - Hidden items restore correctly.

7. Settings
  - Runtime toggles apply.
  - App update checks report success/failure clearly.

## Regression Hotspots

- Pinned package state resolution and bulk-upgrade filtering.
- Timeout/cancellation handling in `CommandExecutor`.
- The 2.0 shell file growth in `MenuBar/Reboot/RebootMenuRootView.swift`.
- Homebrew JSON decode compatibility.
- Continued decomposition of large runtime surfaces such as `PackagesStore`.

## Diagnostics Collection During Bug Reports

- `~/Library/Logs/DiagnosticReports/` crash files.
- Unified logs:
  - `log show --last 1d --predicate 'process == "BrewPackageManager"'`
- Reproduction command output from Terminal for failing Homebrew actions.
- Screenshots from the exact screen involved.
