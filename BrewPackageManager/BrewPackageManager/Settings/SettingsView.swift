//
//  SettingsView.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// The settings panel view.
///
/// Provides user-configurable options including:
/// - Auto-refresh interval
/// - Display filters (show only outdated packages)
/// - Debug mode for verbose logging
/// - CSV export functionality
struct SettingsView: View {

    // MARK: - Environment

    @Environment(AppSettings.self) private var settings
    @Environment(PackagesStore.self) private var store

    // MARK: - Properties

    /// Callback to dismiss the settings panel.
    let onDismiss: () -> Void

    // MARK: - Private Methods

    /// Presents a save panel and exports the package list to CSV.
    private func exportToCSV() {
        let csvContent = store.exportToCSV()

        let savePanel = NSSavePanel()
        savePanel.title = "Export Packages to CSV"
        savePanel.nameFieldStringValue = "homebrew-packages.csv"
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.canCreateDirectories = true

        let response = savePanel.runModal()
        guard response == .OK, let url = savePanel.url else { return }

        do {
            try csvContent.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            // CSV save failed silently
        }
    }

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: .zero) {
            // Header
            PanelHeaderView(title: "Settings", onBack: onDismiss)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Auto-refresh
                    PanelSectionCardView(title: "Auto-Refresh") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Refresh interval")
                                    .font(.body)

                                Spacer()

                                TextField("Seconds", value: $settings.autoRefreshInterval, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .multilineTextAlignment(.trailing)

                                Text("seconds")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text("Set to 0 to disable auto-refresh")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Display options
                    PanelSectionCardView(title: "Display") {
                        Toggle("Show only outdated packages", isOn: $settings.onlyShowOutdated)
                    }

                    // Debug mode
                    PanelSectionCardView(title: "Advanced") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Debug mode", isOn: $settings.debugMode)

                            Text("Enables verbose logging for Homebrew commands")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Export
                    PanelSectionCardView(title: "Export") {
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                exportToCSV()
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Export to CSV…")
                                    Spacer()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(store.packages.isEmpty)

                            Text("Export all installed packages to a CSV file")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
        }
    }
}
