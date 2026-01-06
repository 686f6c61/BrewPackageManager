//
//  AppSettings.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//  Version: 1.6.0
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation
import ServiceManagement
import OSLog

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

    /// Logger for tracking settings operations.
    private let logger = Logger(subsystem: "BrewPackageManager", category: "AppSettings")

    // MARK: - Keys

    /// Keys for storing settings in UserDefaults.
    private enum Keys {
        static let debugMode = "debugMode"
        static let autoRefreshInterval = "autoRefreshInterval"
        static let onlyShowOutdated = "onlyShowOutdated"
        static let checkForUpdatesEnabled = "checkForUpdatesEnabled"
        static let lastUpdateCheck = "lastUpdateCheck"
        static let skippedVersion = "skippedVersion"
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

    /// Whether the app launches at login.
    ///
    /// This is a computed property that reads from and writes to the
    /// ServiceManagement framework. It does not persist to UserDefaults
    /// as the state is managed by the system.
    var launchAtLogin: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                    logger.info("Registered app for launch at login")
                } else {
                    try SMAppService.mainApp.unregister()
                    logger.info("Unregistered app from launch at login")
                }
            } catch {
                logger.error("Failed to update launch at login: \(error.localizedDescription)")
            }
        }
    }

    /// Whether automatic update checking is enabled.
    var checkForUpdatesEnabled: Bool {
        didSet {
            defaults.set(checkForUpdatesEnabled, forKey: Keys.checkForUpdatesEnabled)
        }
    }

    /// Date of the last update check.
    var lastUpdateCheck: Date? {
        didSet {
            if let date = lastUpdateCheck {
                defaults.set(date, forKey: Keys.lastUpdateCheck)
            } else {
                defaults.removeObject(forKey: Keys.lastUpdateCheck)
            }
        }
    }

    /// Version that the user chose to skip.
    var skippedVersion: String? {
        didSet {
            if let version = skippedVersion {
                defaults.set(version, forKey: Keys.skippedVersion)
            } else {
                defaults.removeObject(forKey: Keys.skippedVersion)
            }
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
        checkForUpdatesEnabled = defaults.bool(forKey: Keys.checkForUpdatesEnabled)
        lastUpdateCheck = defaults.object(forKey: Keys.lastUpdateCheck) as? Date
        skippedVersion = defaults.string(forKey: Keys.skippedVersion)

        // Set default interval if not previously set
        if autoRefreshInterval == 0 {
            autoRefreshInterval = 300  // 5 minutes default
        }

        // Enable updates by default
        if !defaults.bool(forKey: "hasSetUpdateCheckDefault") {
            checkForUpdatesEnabled = true
            defaults.set(true, forKey: "hasSetUpdateCheckDefault")
        }
    }
}
