# Changelog

All notable changes to BrewPackageManager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.7.0] - 2026-01-07

### Added

#### Services Manager
- **Homebrew Services Management**
  - View all installed Homebrew services with real-time status
  - Start, stop, and restart services directly from the app
  - Status indicators: Running (green), Stopped (gray), Error (red)
  - Service information display: PID, user, plist path
  - Summary statistics: running vs stopped services count
  - Thread-safe operations using actor-based architecture

#### Cleanup & Cache Management
- **Storage Optimization**
  - View cache size and cached files count
  - Identify old formula versions ready for cleanup
  - Two cleanup modes:
    - Clean old versions only
    - Clear entire download cache (--prune=all)
  - Real-time cache size calculation using `du` command
  - Cleanup recommendation when cache exceeds 500 MB or >5 old versions
  - Confirmation dialogs with size information
  - Success messages showing freed disk space

#### Dependencies Management
- **Package Dependency Viewer**
  - View dependencies for all installed packages
  - Dependency tree visualization with counts
  - Search filter for quick package lookup
  - Summary statistics: total packages, total dependencies
  - Dependency types displayed:
    - Direct dependencies
    - Optional dependencies
    - Build-only dependencies
    - Reverse dependencies (what uses this package)
  - "No dependencies" indicator for independent packages
  - Visual indicators for packages used by others

#### History & Statistics
- **Operation History Tracking**
  - Persistent history of all operations (install, upgrade, uninstall, etc.)
  - Chronological display with relative timestamps
  - Filter by operation type (Install, Upgrade, Services, Cleanup, etc.)
  - Operation icons and color-coded status
  - Success/failure indicators
  - Clear history option with confirmation
  - Stores up to 1000 most recent entries

- **Usage Statistics**
  - Total operations count and success rate percentage
  - Operations breakdown by type with visual bars
  - Most installed packages (top 10)
  - Most upgraded packages (top 10)
  - Interactive statistics cards
  - Empty states for new installations

#### Technical Improvements
- New modular architecture with 4 major feature modules:
  - `Services` module: BrewService model, ServicesClient actor, ServicesStore, ServicesView
  - `Cleanup` module: CleanupInfo model, CleanupClient actor, CleanupStore, CleanupView
  - `Dependencies` module: DependencyInfo model, DependenciesClient actor, DependenciesStore, DependenciesView
  - `History` module: HistoryEntry model, HistoryDatabase actor, HistoryStore, HistoryView, StatisticsView
- All clients use actor pattern for thread-safe operations
- All stores use @Observable macro for SwiftUI integration
- Consistent error handling with AppError enum
- JSON-based persistence for history using UserDefaults
- Comprehensive OSLog logging for all operations

### Changed
- Updated app version from 1.6.0 to 1.7.0
- MenuBarRoute extended with 5 new navigation cases
- MainMenuContentView now includes "Tools" section with 5 new features
- MenuBarRootView updated with navigation handlers for all new views
- HelpView feature list updated with 5 new capabilities
- Enhanced navigation architecture supporting complex view hierarchies

### User Interface
- New "Tools" section in main menu with:
  - Services (gear.badge icon)
  - Cleanup & Cache (trash.circle icon)
  - Dependencies (link.circle icon)
  - History (clock.arrow.circlepath icon)
  - Statistics (chart.bar icon)
- Consistent panel-based UI following existing design patterns
- Smooth animations for all navigation transitions
- Loading states and empty states for all views
- Confirmation dialogs for destructive operations
- Real-time progress indicators for long-running tasks

## [1.6.0] - 2026-01-06

### Added

#### Launch at Login
- **Launch at Login Toggle**
  - New "General" section in Settings with launch at login control
  - Uses modern ServiceManagement framework (SMAppService) for macOS 13+
  - Seamless integration with system login items
  - Automatic state synchronization with macOS preferences

#### Check for Updates
- **Automatic Update Checking**
  - Checks for new releases on GitHub on app launch
  - Configurable automatic checking (enabled by default)
  - Respects 24-hour minimum interval between automatic checks
  - Manual "Check for Updates Now" button in Settings
  - Last checked timestamp display

- **Update Notifications**
  - Alert dialog when updates are available
  - Displays version number, release name, and notes preview
  - Three action options:
    - "Download" - Opens GitHub release page in browser
    - "Skip This Version" - Permanently ignores specific release
    - "Remind Me Later" - Dismisses until next check

- **GitHub Integration**
  - Queries GitHub Releases API for latest version
  - 10-second timeout for network requests
  - Semantic version comparison (X.Y.Z format)
  - Handles network errors gracefully

#### Technical Improvements
- New `Updates` module with components:
  - `GitHubClient` actor for thread-safe API access
  - `UpdateChecker` for business logic coordination
  - `VersionComparator` for semantic version parsing
  - `ReleaseInfo` model for GitHub API responses
  - `UpdateCheckResult` enum for result states
- Extended `AppError` with update-related error cases
- ServiceManagement framework integration for login items

### Changed
- Updated app version from 1.5.0 to 1.6.0
- Settings view reorganized with new "General" and "Updates" sections
- Enhanced `AppSettings` with computed `launchAtLogin` property
- MenuBarRootView now triggers update check on launch
- HelpView updated with all features including search and new v1.6.0 capabilities
- Fixed GitHub repository URL in HelpView

## [1.5.0] - 2026-01-06

### Added

#### Package Search & Installation
- **Search Functionality**
  - Search for available Homebrew packages (formulae and casks)
  - Real-time search with text input field
  - Type filtering: All packages, Formulae only, or Casks only
  - Results limited to first 15 matches with "More results available" hint
  - Empty state and error handling with retry option

- **Package Installation**
  - Install packages directly from search results
  - Installation confirmation dialog with package description
  - Real-time progress indicator during installation
  - Visual states: Installing, Installed, Failed
  - Automatic package list refresh after successful installation
  - Package status badges showing installation state

- **Search Result Display**
  - Package name and type icon (formula/cask)
  - Package description (when available)
  - Installation status badge for already installed packages
  - "Install" button for available packages
  - Context menu with "Show Details" and "Install" options
  - Hover highlighting for better UX

- **Navigation Enhancement**
  - New "Search Packages..." menu item in main view
  - Dedicated search view with back navigation
  - Package info view accessible from search results
  - Smooth animated transitions between views

#### Technical Improvements
- New search state management with SearchState enum (idle, searching, loaded, error)
- SearchResult model for managing search data and caching
- Extended BrewPackagesClient with searchPackages() and installPackage() methods
- PackagesStore enhancements for search and installation operations
- Proper timeout handling: 30 seconds for search, 10 minutes for installation
- Thread-safe operation tracking for concurrent installations

### Changed
- Updated app version from 1.0.0 to 1.5.0
- Enhanced MenuBarRoute with search navigation case
- Extended MainMenuContentView with search action button

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

[1.6.0]: https://github.com/686f6c61/BrewPackageManager/releases/tag/v1.6.0
[1.5.0]: https://github.com/686f6c61/BrewPackageManager/releases/tag/v1.5.0
[1.0.0]: https://github.com/686f6c61/BrewPackageManager/releases/tag/v1.0.0
