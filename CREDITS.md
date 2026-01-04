# Credits

BrewPackageManager builds upon architectural patterns and infrastructure from BrewServicesManager while implementing entirely new package management functionality.

## Based On

**[BrewServicesManager](https://github.com/validatedev/BrewServicesManager)** by validatedev

Licensed under MIT License

BrewServicesManager provided the foundation for command execution, UI patterns, and design system. BrewPackageManager adapts these patterns for package management while adding substantial new functionality.

## Reused Infrastructure

The following components are used directly from BrewServicesManager with minimal or no modifications:

### Command Execution System

Core infrastructure for running shell commands with proper timeout, cancellation, and error handling.

- `CommandExecutor.swift` - Asynchronous process execution with pipe management
- `CommandResult.swift` - Command result data structure
- `CommandExecutorError.swift` - Execution error types
- `BrewLocatorError.swift` - Brew location errors

### Design System

Modern glassmorphic UI components following macOS design guidelines.

- `LayoutConstants.swift` - Spacing, sizing, and layout values
- `AccentGradient.swift` - Brand gradient definitions
- `GlassBackgroundModifier.swift` - Glassmorphic background effects
- `HoverHighlightModifier.swift` - Interactive hover states
- `SectionContainerModifier.swift` - Container styling
- `MenuSectionLabel.swift` - Section headers
- `PanelHeaderView.swift` - Panel navigation headers
- `PanelSectionCardView.swift` - Sectioned card layouts
- `MenuRowButton.swift` - Menu-style button rows

### Utilities

- `AppKitBridge.swift` - AppKit integration helpers

## Adapted Components

These components were adapted from BrewServicesManager patterns but substantially modified for package management:

### Command Infrastructure

- `BrewLocator.swift` - Originally from BrewServicesManager, cleaned up and simplified by removing debug logging and hardcoded paths
- `AppError.swift` - Error model adapted for package-specific failures

### Navigation

- `MenuBarRootView.swift` - Adapted routing pattern with improved height handling for different views

## Original Implementation

The following components are entirely new implementations specific to package management:

### Core Package Management

- `BrewPackage.swift` - Package model with version tracking
- `BrewPackageInfo.swift` - Detailed package metadata with GitHub integration
- `BrewResponseTypes.swift` - JSON response parsing with static decode methods
- `PackageType.swift` - Formula vs Cask distinction
- `PackagesState.swift` - Loading state management
- `PackageOperation.swift` - Package operation tracking
- `BrewPackagesArgumentsBuilder.swift` - Homebrew command construction for packages
- `BrewPackagesClient.swift` - Actor-based Homebrew command execution with JSON decoding
- `BrewPackagesClientProtocol.swift` - Testable client abstraction

### State Management

- `PackagesStore.swift` - Observable store with multi-selection, bulk operations, and progress tracking
- `PackagesDiskCache.swift` - Package data persistence
- `AppSettings.swift` - User preferences (adapted pattern, new implementation)

### User Interface

All UI views are original implementations designed for package management workflows:

- `MenuBarHeaderView.swift` - Header with update badge
- `MainMenuContentView.swift` - Main menu layout with CSV export
- `PackagesSectionView.swift` - Scrollable package list with filtering
- `PackageMenuItemView.swift` - Package row with checkbox selection
- `UpdateActionsSectionView.swift` - Bulk update controls with progress
- `PackageInfoView.swift` - Package details with GitHub/changelog links
- `SettingsView.swift` - Settings panel with CSV export
- `EmptyStateView.swift` - Empty state messaging
- `ErrorView.swift` - Error display

### Features

New functionality not present in BrewServicesManager:

- Multi-package selection with checkboxes
- Bulk package upgrades with progress tracking
- CSV export of package inventory
- Package filtering (show only outdated)
- Direct links to GitHub releases and changelogs
- Persistent cache with background refresh
- Configurable auto-refresh intervals

## Technical Improvements

During development, several improvements were made to both reused and new code:

- Swift 6 strict concurrency compliance
- Actor-based serialization of Homebrew commands
- Asynchronous pipe reading to prevent deadlocks with large JSON output
- Proper cancellation handling throughout async operations
- Modern Swift API usage (replacing vs replacingOccurrences, font.weight vs fontWeight)
- Removal of debug logging in favor of structured OSLog

## Acknowledgments

- **Homebrew** - The package manager that makes this app useful
- **Apple Developer Tools** - Swift, SwiftUI, and SF Symbols
- **validatedev** - For creating BrewServicesManager and demonstrating excellent SwiftUI architecture patterns

## License

This project is licensed under the MIT License. See the LICENSE file for details.

BrewServicesManager is also licensed under the MIT License, allowing reuse and adaptation of its components.
