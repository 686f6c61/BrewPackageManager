# 2.0 Audit

Date: `2026-03-29`
Branch audited: `1.9.0-rethinking`
Target release line: `2.0.0`

## Scope

This audit focuses on four things:

1. Build and test health.
2. External Swift-aware audit tooling running in Docker.
3. Legacy UI/runtime mismatches after the 2.0 shell reboot.
4. Documentation and release readiness for a 2.0 milestone.

## Environment

- macOS host with Xcode `26.4`
- Swift `6.3`
- Docker `29.3.1`
- SwiftLint in Docker: `0.63.2`
- SwiftFormat in Docker: `0.60.1`
- Semgrep in Docker: `1.155.0`

## Commands Run

### Local build and tests

```bash
xcodebuild test \
  -project BrewPackageManager/BrewPackageManager.xcodeproj \
  -scheme BrewPackageManager \
  -destination 'platform=macOS' \
  -derivedDataPath .derived-audit-2
```

Result:
- `TEST SUCCEEDED`
- Logs: `.audit-test-2.log`

### Docker audit lane

```bash
./scripts/audit-swift-in-docker.sh
```

Individual logs from this audit pass:
- `.audit-docker/swiftlint.log`
- `.audit-docker/swiftformat.log`
- `.audit-docker/semgrep.log`

## Current Automated Coverage

- `18` unit tests using the Swift `Testing` framework in `/Users/00b/Desktop/homebrew/BrewPackageManager/BrewPackageManager/BrewPackageManagerTests/BrewPackageManagerTests.swift`
- `3` UI smoke tests in:
  - `/Users/00b/Desktop/homebrew/BrewPackageManager/BrewPackageManager/BrewPackageManagerUITests/BrewPackageManagerUITests.swift`
  - `/Users/00b/Desktop/homebrew/BrewPackageManager/BrewPackageManager/BrewPackageManagerUITests/BrewPackageManagerUITestsLaunchTests.swift`

Coverage quality is acceptable for targeted regression checks, but still thin for a 2.0 shell rewrite.

## Findings

### Resolved: Legacy pre-2.0 SwiftUI screens have been removed

The older menu-screen layer and its supporting UI helpers have now been removed from the repository. The runtime and the repo are aligned on the 2.0 shell under:

- `/Users/00b/Desktop/homebrew/BrewPackageManager/BrewPackageManager/BrewPackageManager/MenuBar/Reboot/RebootMenuRootView.swift`

That removes the biggest directional ambiguity from the 2.0 branch. The remaining blockers are about structure and maintainability, not about two competing UI systems living side by side.

### P0: The new 2.0 shell is already too large to maintain safely as one file

The active shell file is currently `1605` lines:
- `/Users/00b/Desktop/homebrew/BrewPackageManager/BrewPackageManager/BrewPackageManager/MenuBar/Reboot/RebootMenuRootView.swift`

That violates the same architectural goal that motivated the reboot. It should be split into feature-focused subviews/files before final release.

### P0: `PackagesStore` remains the main orchestration hotspot

The current store is `1201` lines and still concentrates too many responsibilities:
- `/Users/00b/Desktop/homebrew/BrewPackageManager/BrewPackageManager/BrewPackageManager/Packages/PackagesStore.swift`

SwiftLint also flags it for:
- file length
- type body length
- function body length
- cyclomatic complexity

This is still the biggest non-UI refactor target for 2.0.

### P1: Formatting and style drift are real, even if functional tests pass

Docker-based audit results:

- `SwiftLint`: `152` violations
- `SwiftFormat --lint`: `71/72` files require formatting
- `Semgrep`: `0` findings from the generic auto ruleset

Top SwiftLint rule counts from this audit:
- `94` `line_length`
- `16` `trailing_whitespace`
- `13` `nesting`
- `7` `function_body_length`
- `6` `type_body_length`
- `5` `file_length`
- `4` `cyclomatic_complexity`

The main conclusion is not “the app is broken”; it is that the codebase needs an explicit style/configuration pass before 2.0 can be considered tidy.

### P1: Tooling configuration is missing

The repo had no pinned Swift formatting version hint for Docker/local tooling before this audit. A new root file was added:
- `/Users/00b/Desktop/homebrew/BrewPackageManager/.swift-version`

This reduces ambiguity for format/lint tooling, but the repo still lacks committed `.swiftlint.yml` and `.swiftformat` configuration.

### P2: Documentation had drifted away from runtime reality

Before this audit, the docs still referenced:
- `1.8.1` as the current release line
- old DMG output names
- cleanup behavior that no longer matches runtime
- old menu flow language that no longer reflects the 2.0 shell

That drift is addressed in this documentation pass.

## What Passed Cleanly

- Full `xcodebuild test` pass on macOS.
- Dockerized `Semgrep` pass with no findings on the current tracked files.
- Versioning and release docs are now aligned to `2.0.0`.

## Recommended Next Steps Before Final 2.0 Release

1. Split `/Users/00b/Desktop/homebrew/BrewPackageManager/BrewPackageManager/BrewPackageManager/MenuBar/Reboot/RebootMenuRootView.swift` into smaller files by screen.
2. Decompose `/Users/00b/Desktop/homebrew/BrewPackageManager/BrewPackageManager/BrewPackageManager/Packages/PackagesStore.swift` into smaller stores/coordinators.
3. Add committed style configs for SwiftLint and SwiftFormat, then fix the repo to that baseline.
4. Expand UI tests to cover the new 2.0 shell flows, not only launch/smoke scenarios.
5. Refresh README screenshots with final 2.0 captures before shipping the release DMG.
