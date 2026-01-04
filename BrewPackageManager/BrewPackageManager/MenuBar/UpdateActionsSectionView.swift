//
//  UpdateActionsSectionView.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// The update actions section for managing package upgrades.
///
/// This view provides:
/// - "Select All Outdated" button to select all packages with updates
/// - "Deselect All" button to clear selection (shown only when packages are selected)
/// - "Update Selected" button to upgrade selected packages
/// - Progress bar during upgrade operations
/// - Current package name being upgraded
///
/// The update button's appearance changes based on selection state:
/// - Blue background when packages are selected
/// - Gray background when no selection
/// - Displays count of selected packages or upgrade progress
struct UpdateActionsSectionView: View {

    // MARK: - Environment

    /// The main packages store.
    @Environment(PackagesStore.self) private var store

    /// User application settings.
    @Environment(AppSettings.self) private var settings

    // MARK: - Computed Properties

    /// Whether any packages are currently selected.
    private var hasSelection: Bool {
        !store.selectedPackageIDs.isEmpty
    }

    /// The number of selected packages.
    private var selectionCount: Int {
        store.selectedPackageIDs.count
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 4) {
            // Select/Deselect buttons
            HStack {
                Button("Select All Outdated") {
                    store.selectAllOutdated()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.blue)

                Spacer()

                if hasSelection {
                    Button("Deselect All") {
                        store.deselectAll()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            // Update selected button
            Button {
                Task {
                    await store.upgradeSelected(debugMode: settings.debugMode)
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")

                    if let progress = store.upgradeProgress {
                        Text("Updating \(progress.completed)/\(progress.total)...")
                    } else if hasSelection {
                        Text("Update Selected (\(selectionCount))")
                    } else {
                        Text("Select Packages to Update")
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(hasSelection ? Color.blue : Color.gray.opacity(0.2))
                .foregroundStyle(hasSelection ? .white : .secondary)
                .clipShape(.rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(!hasSelection || store.isUpgradingSelected)
            .padding(.horizontal)

            // Progress bar
            if let progress = store.upgradeProgress {
                ProgressView(value: Double(progress.completed), total: Double(progress.total))
                    .padding(.horizontal)

                if let current = progress.currentPackage {
                    Text("Upgrading \(current)...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
