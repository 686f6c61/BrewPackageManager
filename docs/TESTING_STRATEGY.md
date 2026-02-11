# Testing Strategy

## Goals

- Keep command execution reliable under real Homebrew output.
- Prevent UI dead states after command failures.
- Ensure package identity and selection logic remain correct across formula/cask.
- Keep release packaging reproducible.

## Automated Test Scope

Current emphasis:

- Unit tests in `BrewPackageManagerTests` for:
  - Settings persistence.
  - Package ID uniqueness by type.
  - Command diagnostics summaries.
  - Upgrade failure state reset.
  - Pinned selection and skip behavior.

Run command:

```bash
xcodebuild \
  -project BrewPackageManager/BrewPackageManager.xcodeproj \
  -scheme BrewPackageManager \
  -configuration Debug \
  -derivedDataPath .derived-audit-clean \
  CODE_SIGNING_ALLOWED=NO \
  test -only-testing:BrewPackageManagerTests
```

## Manual Smoke Checklist

1. Startup and refresh:
  - App opens.
  - Package list renders.
  - No endless loading/updating state.

2. Upgrade flow:
  - Non-pinned outdated package upgrades successfully.
  - Pinned formula is skipped with actionable guidance.

3. Search/install:
  - Search returns typed results.
  - Install updates package list and operation status.

4. Services:
  - Start/stop/restart modifies status as expected.

5. Cleanup:
  - Dry-run metrics load.
  - Cleanup action updates stats and history.

6. Dependencies/history/statistics:
  - Graph loads.
  - History entries are added after operations.

7. Settings:
  - Diagnostics section shows latest command metadata.
  - CSV export handles failure conditions visibly.

## Regression Hotspots

- Pinned package state resolution and bulk upgrade filtering.
- Timeout/cancellation handling in command executor.
- Route transitions between main/search/package info/settings panels.
- Homebrew JSON decode compatibility.

## Diagnostics Collection During Bug Reports

- `~/Library/Logs/DiagnosticReports/` crash files.
- Unified logs:
  - `log show --last 1d --predicate 'process == "BrewPackageManager"'`
- Reproduction command output from terminal for failing Homebrew action.
- Screenshot of app warning modal (if present).
