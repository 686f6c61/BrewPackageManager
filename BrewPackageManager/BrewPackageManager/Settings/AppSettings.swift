//
//  AppSettings.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

/// Observable settings storage backed by UserDefaults.
///
/// This class manages user preferences for the application, automatically
/// persisting changes to UserDefaults. All properties trigger SwiftUI updates
/// when modified.
@MainActor
@Observable
final class AppSettings {

    // MARK: - Properties

    /// The UserDefaults instance for persistence.
    private let defaults: UserDefaults

    // MARK: - Keys

    /// Keys for storing settings in UserDefaults.
    private enum Keys {
        static let debugMode = "debugMode"
        static let autoRefreshInterval = "autoRefreshInterval"
        static let onlyShowOutdated = "onlyShowOutdated"
    }

    // MARK: - Settings

    /// Whether to run Homebrew commands in debug mode with verbose output.
    var debugMode: Bool {
        didSet {
            defaults.set(debugMode, forKey: Keys.debugMode)
        }
    }

    /// Auto-refresh interval in seconds. 0 disables auto-refresh.
    var autoRefreshInterval: Int {
        didSet {
            defaults.set(autoRefreshInterval, forKey: Keys.autoRefreshInterval)
        }
    }

    /// Whether to show only outdated packages in the list.
    var onlyShowOutdated: Bool {
        didSet {
            defaults.set(onlyShowOutdated, forKey: Keys.onlyShowOutdated)
        }
    }

    // MARK: - Initialization

    /// Initializes settings from UserDefaults.
    ///
    /// Loads saved settings or applies default values. The default auto-refresh
    /// interval is 300 seconds (5 minutes) if not previously set.
    ///
    /// - Parameter defaults: The UserDefaults instance to use. Defaults to `.standard`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        debugMode = defaults.bool(forKey: Keys.debugMode)
        autoRefreshInterval = defaults.integer(forKey: Keys.autoRefreshInterval)
        onlyShowOutdated = defaults.bool(forKey: Keys.onlyShowOutdated)

        // Set default interval if not previously set
        if autoRefreshInterval == 0 {
            autoRefreshInterval = 300  // 5 minutes default
        }
    }
}
