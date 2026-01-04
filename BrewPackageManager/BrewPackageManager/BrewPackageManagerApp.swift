//
//  BrewPackageManagerApp.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// The main app entry point for BrewPackageManager.
///
/// This app provides a menu bar interface for managing Homebrew packages on macOS.
/// It creates a `MenuBarExtra` with a dynamic icon that reflects the current state:
/// - Error state when Homebrew is not available
/// - Refreshing indicator during package list updates
/// - Upgrade indicator during package upgrades
/// - Badge when updates are available
/// - Normal state otherwise
///
/// The app maintains two primary state objects:
/// - `PackagesStore`: Manages package data and operations
/// - `AppSettings`: Stores user preferences
@main
struct BrewPackageManagerApp: App {

    // MARK: - State

    /// The main store managing package state and operations.
    @State private var packagesStore = PackagesStore()

    /// User-configurable application settings.
    @State private var appSettings = AppSettings()

    // MARK: - Computed Properties

    /// Determines the menu bar icon based on current app state.
    ///
    /// Icon selection priority:
    /// 1. Error icon if Homebrew is unavailable
    /// 2. Refreshing icon during package refresh
    /// 3. Upgrade icon during package upgrades
    /// 4. Badge icon when outdated packages exist
    /// 5. Normal icon otherwise
    private var iconName: String {
        if !packagesStore.isBrewAvailable {
            return "cube.box.fill"  // Error state
        }

        if packagesStore.isRefreshing {
            return "arrow.triangle.2.circlepath"  // Refreshing
        }

        if packagesStore.isUpgradingSelected {
            return "arrow.up.circle.fill"  // Upgrading
        }

        let outdatedCount = packagesStore.outdatedCount
        if outdatedCount > 0 {
            return "cube.box.badge.ellipsis"  // Updates available
        }

        return "cube.box.fill"  // Normal state
    }

    // MARK: - Scene

    var body: some Scene {
        MenuBarExtra("Brew Package Manager", systemImage: iconName) {
            MenuBarRootView()
                .environment(packagesStore)
                .environment(appSettings)
        }
        .menuBarExtraStyle(.window)
        .windowResizability(.contentSize)
    }
}
