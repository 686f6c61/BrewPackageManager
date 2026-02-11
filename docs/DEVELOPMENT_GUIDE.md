# Development Guide

## Prerequisites

- macOS 15.0+.
- Xcode 16+.
- Homebrew installed and working in terminal.

## Clone and Build

```bash
git clone https://github.com/686f6c61/BrewPackageManager.git
cd BrewPackageManager
```

Debug build using helper script:

```bash
./build.sh
```

Direct Xcode build:

```bash
xcodebuild \
  -project BrewPackageManager/BrewPackageManager.xcodeproj \
  -scheme BrewPackageManager \
  -configuration Debug \
  ENABLE_APP_SANDBOX=NO \
  build
```

## Run Locally

- From Xcode with `BrewPackageManager` scheme.
- Or open the built app from derived data path emitted by `build.sh`.

## Tests

Run unit tests:

```bash
xcodebuild \
  -project BrewPackageManager/BrewPackageManager.xcodeproj \
  -scheme BrewPackageManager \
  -configuration Debug \
  -derivedDataPath .derived-audit-clean \
  CODE_SIGNING_ALLOWED=NO \
  test -only-testing:BrewPackageManagerTests
```

## Packaging

Create a release DMG:

```bash
./create-dmg.sh
```

Output:

- `dmg/BrewPackageManager-1.8.0.dmg`

## Coding Expectations

- Keep shell calls in clients, not in views.
- Keep state mutations in stores.
- Keep CLI argument composition in `BrewPackagesArgumentsBuilder`.
- Use typed domain models instead of ad-hoc dictionaries.
- Handle cancellation and timeout explicitly in long operations.
- Update docs in `docs/` when behavior changes.

## Common Debugging

- Homebrew command behavior:
  - Reproduce same command directly in terminal.
- App command diagnostics:
  - Open `Settings > Advanced` for the last command metadata.
- macOS crash files:
  - `~/Library/Logs/DiagnosticReports/`
- Unified logs for this app:
  - `log show --last 1d --predicate 'process == "BrewPackageManager"'`
