//
//  PackageInfoView.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// A detailed information view for a Homebrew package.
///
/// This view displays comprehensive package information including:
/// - Package description
/// - Version information (installed, latest, linked)
/// - Links (homepage, release notes, GitHub repository)
/// - License
///
/// All external links open in the user's default browser via `openURL`.
struct PackageInfoView: View {

    // MARK: - Properties

    /// The package information to display.
    let info: BrewPackageInfo

    /// Callback to dismiss the view and return to main menu.
    let onDismiss: () -> Void

    // MARK: - Environment

    /// System environment action to open URLs in the default browser.
    @Environment(\.openURL) private var openURL

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            // Header
            PanelHeaderView(title: info.name, onBack: onDismiss)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Description
                    if let desc = info.desc {
                        PanelSectionCardView(title: "Description") {
                            Text(desc)
                                .font(.body)
                        }
                    }

                    // Versions
                    PanelSectionCardView(title: "Versions") {
                        VStack(alignment: .leading, spacing: 8) {
                            if let installed = info.installedVersions?.first {
                                InfoRow(label: "Installed", value: installed.version)
                            }

                            if let stable = info.versions.stable {
                                InfoRow(label: "Latest", value: stable)
                            }

                            if let linked = info.linkedKeg {
                                InfoRow(label: "Linked", value: linked)
                            }
                        }
                    }

                    // Links
                    PanelSectionCardView(title: "Links") {
                        VStack(alignment: .leading, spacing: 8) {

                            if let homepage = info.homepage, let url = URL(string: homepage) {
                                Button {
                                    openURL(url)
                                } label: {
                                    HStack {
                                        Image(systemName: "safari")
                                        Text("Homepage")
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                    }
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.blue)
                            }

                            if let changelogURL = info.changelogURL {
                                Button {
                                    openURL(changelogURL)
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text")
                                        Text("Release Notes")
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                    }
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.blue)
                            }

                            if let githubURL = info.githubURL {
                                Button {
                                    openURL(githubURL)
                                } label: {
                                    HStack {
                                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                                        Text("GitHub Repository")
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                    }
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.blue)
                            }
                        }
                    }

                    // License
                    if let license = info.license {
                        PanelSectionCardView(title: "License") {
                            Text(license)
                                .font(.body)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - InfoRow

/// A row displaying a label-value pair in package information sections.
private struct InfoRow: View {

    /// The label text (e.g., "Installed", "Latest").
    let label: String

    /// The value text (e.g., version number).
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.body.weight(.medium))
        }
    }
}
