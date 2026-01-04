//
//  MenuBarRootView.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// The root navigation view for the menu bar interface.
///
/// This view manages navigation between different screens:
/// - Main menu: Package list and primary actions
/// - Settings: User preferences
/// - Help: Documentation and support
/// - Package Info: Detailed package information
///
/// Navigation is handled via a `MenuBarRoute` enum with animated transitions.
/// The view also handles auto-refresh on appear if no initial refresh has occurred.
struct MenuBarRootView: View {

    // MARK: - Environment

    /// The main packages store.
    @Environment(PackagesStore.self) private var store

    /// User application settings.
    @Environment(AppSettings.self) private var settings

    // MARK: - State

    /// The current navigation route.
    @State private var route: MenuBarRoute = .main

    // MARK: - Computed Properties

    /// Returns the appropriate menu width based on the current route.
    private var menuContentWidth: CGFloat {
        switch route {
        case .settings:
            LayoutConstants.settingsMenuWidth
        case .help:
            LayoutConstants.mainMenuWidth
        case .packageInfo:
            LayoutConstants.serviceInfoMenuWidth
        case .main:
            LayoutConstants.mainMenuWidth
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch route {
            case .main:
                MainMenuContentView(
                    onSettings: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            route = .settings
                        }
                    },
                    onHelp: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            route = .help
                        }
                    },
                    onPackageInfo: { package in
                        Task {
                            await store.fetchPackageInfo(
                                package.name,
                                debugMode: settings.debugMode
                            )
                            if let info = store.selectedPackageInfo {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    route = .packageInfo(info)
                                }
                            }
                        }
                    }
                )
                .transition(.move(edge: .leading))

            case .settings:
                SettingsView {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        route = .main
                    }
                }
                .transition(.move(edge: .trailing))

            case .help:
                HelpView {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        route = .main
                    }
                }
                .transition(.move(edge: .trailing))

            case .packageInfo(let info):
                PackageInfoView(info: info) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        route = .main
                        store.clearPackageInfo()
                    }
                }
                .transition(.move(edge: .trailing))
            }
        }
        .frame(width: menuContentWidth)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            Task {
                // Only start auto-refresh if not already refreshing
                if !store.isRefreshing && store.lastRefresh == nil {
                    await store.runAutoRefresh(
                        intervalSeconds: settings.autoRefreshInterval,
                        debugMode: settings.debugMode
                    )
                }
            }
        }
    }
}
