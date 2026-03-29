# Development Guide

## Prerequisites

- macOS 15.0+
- Xcode 26+
- Homebrew installed and working in Terminal
- Docker 29+ for the external audit lane

## Clone and Build

```bash
git clone https://github.com/686f6c61/BrewPackageManager.git
cd BrewPackageManager
```

Debug build using the helper script:

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

- From Xcode with the `BrewPackageManager` scheme.
- Or open the built app from the derived-data path emitted by `build.sh`.

## Tests

Full local test pass:

```bash
xcodebuild \
  -project BrewPackageManager/BrewPackageManager.xcodeproj \
  -scheme BrewPackageManager \
  -destination 'platform=macOS' \
  -derivedDataPath .derived-audit-2 \
  test
```

## Docker Audit Lane

Run the external static-audit lane with Docker:

```bash
./scripts/audit-swift-in-docker.sh
```

Outputs:
- `.audit-docker/swiftlint.log`
- `.audit-docker/swiftformat.log`
- `.audit-docker/semgrep.log`

## Packaging

Create a release DMG:

```bash
./create-dmg.sh
```

Output:
- `dmg/BrewPackageManager-2.0.0.dmg`

## Coding Expectations

- Keep shell calls in clients, not in views.
- Keep state mutations in stores.
- Keep CLI argument composition in `BrewPackagesArgumentsBuilder`.
- Use typed domain models instead of ad-hoc dictionaries.
- Handle cancellation and timeout explicitly in long operations.
- Update docs in `docs/` when behavior changes.
- Prefer smaller SwiftUI screen files over giant multi-screen files.

## Common Debugging

- Homebrew command behavior:
  - Reproduce the same command directly in Terminal.
- App command diagnostics:
  - Enable debug mode and inspect the most recent command metadata.
- macOS crash files:
  - `~/Library/Logs/DiagnosticReports/`
- Unified logs for this app:
  - `log show --last 1d --predicate 'process == "BrewPackageManager"'`
