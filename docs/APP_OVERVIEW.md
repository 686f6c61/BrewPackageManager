# App Overview

## What This App Is

`BrewPackageManager` is a native macOS menu bar app for operating Homebrew from a GUI while keeping Homebrew behavior explicit and transparent.

It supports:

- Installed package visibility (formulae and casks).
- Outdated detection and selective upgrades.
- Package search and installation.
- Service control (`brew services`).
- Cleanup and cache operations.
- Dependency inspection.
- History and statistics.
- App update checks from GitHub releases.

## Runtime Requirements

- macOS 15.0+.
- Homebrew available at standard locations:
  - `/opt/homebrew/bin/brew` (Apple Silicon).
  - `/usr/local/bin/brew` (Intel).

## Primary User Journeys

1. Open menu bar app and inspect outdated packages.
2. Select outdated items and run bulk upgrade.
3. Skip pinned formulae and guide user to `brew unpin`.
4. Search/install missing package from in-app search.
5. Manage services and cleanup tasks without terminal context switching.
6. Export package metadata and inspect operation history.

## Product Constraints

- App must execute Homebrew commands, so App Sandbox is disabled for local builds and releases.
- Shell execution must remain bounded and cancellable to avoid memory issues and UI hangs.
- UI state should never be left in a misleading "running" mode after failure.

## Non-goals

- Replacing Homebrew behavior or policy.
- Hiding command failures from users.
- Introducing package manager semantics beyond Homebrew CLI behavior.
