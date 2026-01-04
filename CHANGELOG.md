# Changelog

All notable changes to BrewPackageManager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-04

### Initial Release

BrewPackageManager 1.0.0 is a native macOS menu bar application for managing Homebrew packages, built with Swift 6 and SwiftUI for macOS 15.0+.

### Added

#### Core Features
- **Package Management**
  - View all installed Homebrew packages (formulae and casks)
  - Real-time detection of outdated packages with visual indicators
  - Detailed package information view with version history
  - Support for both Apple Silicon (`/opt/homebrew`) and Intel (`/usr/local`) Homebrew installations

- **Update Operations**
  - Bulk package updates with checkbox selection
  - "Select All Outdated" quick action
  - Individual package upgrade support
  - Progress tracking with current package name and completion percentage
  - Upgrade all packages at once

- **Package Information**
  - Package description and metadata
  - Installed vs. latest version comparison
  - License information display
  - Direct links to:
    - Package homepage
    - GitHub repository
    - Release notes/changelog

- **Uninstall Functionality**
  - Right-click context menu for package removal
  - Confirmation workflow to prevent accidental deletion

#### User Interface
- **Menu Bar Integration**
  - Dynamic menu bar icon reflecting app state:
    - Normal state: Cube icon
    - Updates available: Cube with badge
    - Refreshing: Rotating arrows
    - Upgrading: Arrow up circle
  - Compact, native macOS design

- **Navigation**
  - Main package list view
  - Settings panel
  - Package detail view
  - Help documentation

- **Display Options**
  - "Outdated only" filter toggle
  - Package count badge
  - Empty state when all packages are up-to-date
  - Error state with recovery suggestions

#### Settings & Configuration
- **Auto-Refresh**
  - Configurable refresh interval (in seconds)
  - Disable option (set to 0)
  - Automatic package list updates in background

- **Display Preferences**
  - "Show only outdated packages" filter
  - Debug mode for verbose Homebrew command logging

- **Export Functionality**
  - Export complete package inventory to CSV format
  - Includes: name, type, versions, outdated status, tap, description, homepage
  - Customizable save location

#### Technical Features
- **Modern Swift 6 Architecture**
  - Strict concurrency with MainActor isolation
  - Observable macro for reactive state management
  - Actor-based serial command execution
  - Async/await for all Homebrew operations

- **Robust Command Execution**
  - Asynchronous stdout/stderr pipe reading prevents deadlocks
  - Timeout support for long-running operations
  - Cancellation support for graceful interruption
  - Environment variable control (no auto-update, no cleanup)

- **Data Persistence**
  - Disk-based package cache for instant startup
  - UserDefaults for settings persistence
  - Background cache updates to avoid UI blocking

- **Error Handling**
  - Comprehensive error types with localized descriptions
  - Recovery suggestions for common failures
  - Graceful degradation when Homebrew is unavailable
  - User-friendly error messages

- **Performance Optimizations**
  - Lazy package list loading
  - Background priority for cache operations
  - Efficient JSON parsing with Codable
  - Minimal memory footprint

#### Design System
- **UI Components**
  - Glass effect backgrounds (macOS 26+) with fallback to ultra-thin material
  - Hover highlight modifiers for interactive elements
  - Section container styling for grouped content
  - Reusable panel headers and cards

- **Visual Design**
  - Warm amber accent gradient (#FBB040)
  - Consistent spacing and padding via LayoutConstants
  - Dark mode support with system appearance integration
  - SF Symbols throughout for native feel

### Technical Details

#### Requirements
- macOS 15.0 or later
- Xcode 16.0+ (for building from source)
- Swift 6.0
- Homebrew installed at standard paths

#### Dependencies
- SwiftUI for declarative UI
- Observation framework for state management
- OSLog for structured logging
- AppKit for native macOS integration

#### Architecture
- **Modules**
  - `Shell`: Command execution infrastructure
  - `Brew`: Homebrew API integration and JSON parsing
  - `Packages`: State management and business logic
  - `MenuBar`: SwiftUI views and navigation
  - `Settings`: User preferences management
  - `Design`: Reusable UI components and modifiers
  - `Components`: Generic UI elements
  - `Utilities`: Helper functions and AppKit bridges

#### Known Limitations
- Requires App Sandbox to be disabled for Homebrew command execution
- macOS 15.0+ required for Observation framework support
- No undo functionality for uninstall operations
- Limited to packages managed by Homebrew (no native macOS packages)

### Credits

This project builds upon infrastructure from [BrewServicesManager](https://github.com/validatedev/BrewServicesManager) by validatedev (MIT License).

Reused components include:
- Command execution system
- Design system (modifiers, gradients, layout constants)
- Generic UI components

The package management logic, state management, CSV export functionality, and UI layout are original implementations for this project.

### License

MIT License - Copyright (c) 2026

[1.0.0]: https://github.com/686f6c61/BrewPackageManager/releases/tag/v1.0.0
