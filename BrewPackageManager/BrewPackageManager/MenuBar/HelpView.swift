//
//  HelpView.swift
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

/// The help and documentation view.
///
/// This view provides comprehensive information about the application:
/// - App name, version, and description
/// - Feature list
/// - License information (MIT)
/// - Source code repository link
/// - Credits and technical details
///
/// Users can navigate to the GitHub repository via the provided link.
struct HelpView: View {

    // MARK: - Properties

    /// Callback to dismiss the view and return to main menu.
    let onDismiss: () -> Void

    // MARK: - Environment

    /// System environment action to open URLs in the default browser.
    @Environment(\.openURL) private var openURL

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            PanelHeaderView(title: "Help", onBack: onDismiss)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // App info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Brew Package Manager")
                            .font(.headline)

                        Text("Version \(appVersion)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("A macOS menu bar application for managing Homebrew packages.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sectionContainer()

                    // Features
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Features")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 4) {
                            FeatureRow(text: "View installed packages and casks")
                            FeatureRow(text: "Check for available updates")
                            FeatureRow(text: "Search for and install new packages")
                            FeatureRow(text: "Upgrade packages individually or in bulk")
                            FeatureRow(text: "Uninstall packages")
                            FeatureRow(text: "Export package list to CSV")
                            FeatureRow(text: "Auto-refresh package list")
                            FeatureRow(text: "Launch at login")
                            FeatureRow(text: "Check for app updates automatically")
                            FeatureRow(text: "Manage Homebrew services")
                            FeatureRow(text: "Cleanup and cache management")
                            FeatureRow(text: "View package dependencies")
                            FeatureRow(text: "Track operation history")
                            FeatureRow(text: "View usage statistics")
                        }
                        .font(.caption)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sectionContainer()

                    // License
                    VStack(alignment: .leading, spacing: 8) {
                        Text("License")
                            .font(.headline)

                        Text("MIT License")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Copyright (c) 2026")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sectionContainer()

                    // Repository
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source Code")
                            .font(.headline)

                        Button {
                            if let url = URL(string: "https://github.com/686f6c61/BrewPackageManager") {
                                openURL(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "link")
                                Text("View on GitHub")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)

                        Text("Licensed under MIT License")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sectionContainer()

                    // Credits
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Credits")
                            .font(.headline)

                        Text("Built with Swift and SwiftUI for macOS 15.0+")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Infrastructure based on BrewServicesManager")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sectionContainer()
                }
                .padding()
            }
        }
        .frame(width: LayoutConstants.mainMenuWidth)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }
}

// MARK: - FeatureRow

/// A row displaying a single feature in the help view.
struct FeatureRow: View {

    /// The feature description text.
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}
