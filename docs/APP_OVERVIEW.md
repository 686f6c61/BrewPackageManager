# App Overview

## What This App Is

`BrewPackageManager` is a native macOS menu bar app for operating Homebrew from a GUI while keeping Homebrew behavior explicit and transparent.

The active 2.0 shell is organized around four primary surfaces:

- `Overview`
- `Search`
- `Tools`
- `Settings`

It supports:

- Installed package visibility.
- Outdated detection with visible-action filtering.
- Package search and installation.
- Service control (`brew services`).
- Cleanup and cache operations.
- Dependency inspection.
- History and statistics.
- App update checks from GitHub releases.
- Hidden package/update state.

## Terminology

Homebrew terms appear throughout the app and docs:

- `Formulae`: CLI tools, libraries, and development packages.
- `Casks`: macOS apps and app-like binaries.

For product copy, it is reasonable to translate these as:

- `CLI Tools`
- `Mac Apps`

## Runtime Requirements

- macOS 15.0+.
- Homebrew available at standard locations:
  - `/opt/homebrew/bin/brew` (Apple Silicon).
  - `/usr/local/bin/brew` (Intel).

## Primary User Journeys

1. Open the menu bar app and inspect the overview.
2. Run a visible bulk update without accidentally including pinned or hidden items.
3. Search and install a missing package from the in-app search flow.
4. Review package details without losing navigation context.
5. Manage services and cleanup tasks without terminal context switching.
6. Inspect history/statistics when something goes wrong.
7. Restore hidden items when the visible inventory becomes too aggressive.

## Product Constraints

- The app must execute Homebrew commands, so App Sandbox is disabled for local builds and releases.
- Shell execution must remain bounded and cancellable to avoid memory issues and UI hangs.
- UI state should never be left in a misleading running state after failure.
- Homebrew output is an external contract and may change independently of the app.

## Current 2.0 Caveat

The pre-2.0 SwiftUI menu layer has already been retired. The remaining 2.0 caveat is maintainability: the reboot shell is still too large and the main package store still owns too many responsibilities. That ongoing work is tracked explicitly in `AUDIT_2_0.md`.
