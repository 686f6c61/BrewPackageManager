//
//  MainMenuContentView.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//  Version: 1.5.0
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// The main menu content view displaying packages and primary actions.
///
/// This view composes the primary menu interface with:
/// - Header with app branding
/// - Package list section
/// - Update actions section (when updates are available)
/// - App actions (Refresh, Search, Settings, Help, Quit)
/// - Version footer
///
/// Navigation callbacks are provided for transitioning to Search, Settings, Help,
/// and Package Info views.
struct MainMenuContentView: View {

    // MARK: - Environment

    /// The main packages store.
    @Environment(PackagesStore.self) private var store

    /// User application settings.
    @Environment(AppSettings.self) private var settings

    // MARK: - Properties

    /// Callback to navigate to the settings view.
    let onSettings: () -> Void

    /// Callback to navigate to the help view.
    let onHelp: () -> Void

    /// Callback to navigate to package detail view.
    let onPackageInfo: (BrewPackage) -> Void

    /// Callback to navigate to the search view.
    let onSearch: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            MenuBarHeaderView()

            Divider()

            // Packages section
            PackagesSectionView(onPackageInfo: onPackageInfo)

            Divider()

            // Update actions section
            if store.outdatedCount > 0 {
                MenuSectionLabel(title: "Updates")
                UpdateActionsSectionView()
                Divider()
            }

            // App section
            MenuSectionLabel(title: "App")

            MenuRowButton("Refresh", systemImage: "arrow.clockwise", isEnabled: !store.isRefreshing) {
                Task {
                    await store.refresh(debugMode: settings.debugMode, force: true)
                }
            }

            MenuRowButton("Search Packages…", systemImage: "magnifyingglass", showDisclosure: true) {
                onSearch()
            }

            MenuRowButton("Settings…", systemImage: "gear", showDisclosure: true) {
                onSettings()
            }

            MenuRowButton("Help", systemImage: "questionmark.circle", showDisclosure: true) {
                onHelp()
            }

            Divider()

            HStack {
                MenuRowButton("Quit", systemImage: "power") {
                    AppKitBridge.quit()
                }

                Spacer()

                Text("v1.5.0")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 12)
            }
        }
    }
}
