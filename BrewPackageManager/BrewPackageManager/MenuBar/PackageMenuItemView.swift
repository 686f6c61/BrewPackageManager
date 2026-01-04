//
//  PackageMenuItemView.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// A menu item view representing a single Homebrew package.
///
/// This view displays:
/// - Checkbox (for outdated packages) or package type icon
/// - Package name and version information
/// - Update indicator showing available version (if outdated)
/// - Operation status (running, failed)
/// - Info button to view package details
///
/// Interaction:
/// - Tap checkbox to select/deselect for bulk updates
/// - Tap info button to view detailed package information
/// - Right-click for context menu with "View Info" and "Uninstall" options
/// - Hover for highlight effect
struct PackageMenuItemView: View {

    // MARK: - Environment

    /// The main packages store.
    @Environment(PackagesStore.self) private var store

    /// User application settings.
    @Environment(AppSettings.self) private var settings

    // MARK: - Properties

    /// The package to display.
    let package: BrewPackage

    /// Callback invoked when the info button is tapped.
    let onInfo: () -> Void

    // MARK: - Computed Properties

    /// Whether this package is currently selected for bulk operations.
    private var isSelected: Bool {
        store.selectedPackageIDs.contains(package.id)
    }

    /// The current operation status for this package, if any.
    private var operation: PackageOperation? {
        store.packageOperations[package.id]
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            // Checkbox (only for outdated packages)
            if package.hasUpdate {
                Button {
                    store.toggleSelection(for: package.id)
                } label: {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isSelected ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 20)
            } else {
                Image(systemName: package.type.systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }

            // Package name and version
            VStack(alignment: .leading, spacing: 2) {
                Text(package.displayName)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(package.installedVersion)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if package.hasUpdate, let current = package.currentVersion {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.orange)

                        Text(current)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            // Operation status
            if let operation {
                switch operation.status {
                case .idle, .succeeded:
                    EmptyView()
                case .running:
                    ProgressView()
                        .controlSize(.mini)
                case .failed:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            // Info button
            Button {
                onInfo()
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .hoverHighlight()
        .contextMenu {
            Button {
                onInfo()
            } label: {
                Label("View Info", systemImage: "info.circle")
            }

            Divider()

            Button(role: .destructive) {
                Task {
                    await store.uninstallPackage(package.id, debugMode: settings.debugMode)
                }
            } label: {
                Label("Uninstall", systemImage: "trash")
            }
        }
    }
}
