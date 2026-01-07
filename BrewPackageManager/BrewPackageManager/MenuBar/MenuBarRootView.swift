//
//  MenuBarRootView.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//  Version: 1.7.0
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
/// - Search: Package search and installation
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
        case .help, .search, .main, .services, .cleanup, .dependencies, .history, .statistics:
            LayoutConstants.mainMenuWidth
        case .packageInfo:
            LayoutConstants.serviceInfoMenuWidth
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
                    },
                    onSearch: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            route = .search
                        }
                    },
                    onServices: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            route = .services
                        }
                    },
                    onCleanup: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            route = .cleanup
                        }
                    },
                    onDependencies: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            route = .dependencies
                        }
                    },
                    onHistory: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            route = .history
                        }
                    },
                    onStatistics: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            route = .statistics
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

            case .search:
                SearchView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            route = .main
                            store.clearSearch()
                        }
                    },
                    onPackageInfo: { result in
                        Task {
                            await store.fetchSearchResultInfo(result, debugMode: settings.debugMode)
                            if let updated = store.searchResults.first(where: { $0.id == result.id }),
                               let info = updated.info {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    route = .packageInfo(info)
                                }
                            }
                        }
                    }
                )
                .transition(.move(edge: .trailing))

            case .packageInfo(let info):
                PackageInfoView(info: info) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        route = .main
                        store.clearPackageInfo()
                    }
                }
                .transition(.move(edge: .trailing))

            case .services:
                ServicesView {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        route = .main
                    }
                }
                .transition(.move(edge: .trailing))

            case .cleanup:
                CleanupView {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        route = .main
                    }
                }
                .transition(.move(edge: .trailing))

            case .dependencies:
                DependenciesView {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        route = .main
                    }
                }
                .transition(.move(edge: .trailing))

            case .history:
                HistoryView {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        route = .main
                    }
                }
                .transition(.move(edge: .trailing))

            case .statistics:
                StatisticsView {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        route = .main
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

                // Check for updates if enabled and >24h since last check
                if settings.checkForUpdatesEnabled,
                   UpdateChecker.shouldCheckForUpdates(lastCheck: settings.lastUpdateCheck) {
                    await store.checkForUpdates(settings: settings, manual: false)
                }
            }
        }
    }
}
