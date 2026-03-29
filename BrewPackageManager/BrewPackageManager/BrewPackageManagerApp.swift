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

/// The main app entry point for Brew Package Manager.
///
/// The visible menu bar item is managed through AppKit so we can distinguish
/// left click (open the popover) from right click (show a quick actions menu).
@main
struct BrewPackageManagerApp: App {

    // MARK: - App Lifecycle

    @NSApplicationDelegateAdaptor(BrewPackageManagerAppDelegate.self) private var appDelegate

    // MARK: - Dependencies

    private let packagesStore: PackagesStore
    private let appSettings: AppSettings

    // MARK: - Initialization

    init() {
        let packagesStore = PackagesStore()
        let appSettings = AppSettings()

        self.packagesStore = packagesStore
        self.appSettings = appSettings

        appDelegate.configure(packagesStore: packagesStore, appSettings: appSettings)
    }

    // MARK: - Scene

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appSettings) { }
            CommandGroup(replacing: .appTermination) {
                Button("Quit Brew Package Manager") {
                    AppKitBridge.quit()
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}
