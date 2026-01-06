//
//  SearchResultRow.swift
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

/// A row displaying a single search result.
///
/// This view shows package information including type, name, description,
/// and installation status. Users can install available packages or view
/// details via the context menu.
struct SearchResultRow: View {

    // MARK: - Properties

    /// The search result to display.
    let result: SearchResult

    /// Current installation operation status for this package.
    let operation: PackageOperation?

    /// Callback to initiate package installation.
    let onInstall: () -> Void

    /// Callback to show package details.
    let onShowInfo: () -> Void

    // MARK: - State

    /// Whether the mouse is hovering over this row.
    @State private var isHovering = false

    // MARK: - Computed Properties

    /// Whether the package is currently being installed.
    private var isInstalling: Bool {
        operation?.status == .running
    }

    /// Whether the installation failed.
    private var installFailed: Bool {
        operation?.status == .failed
    }

    /// Whether the installation succeeded recently.
    private var installSucceeded: Bool {
        operation?.status == .succeeded
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Package type icon
            Image(systemName: result.type.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: LayoutConstants.menuRowIconWidth)

            // Package info
            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .font(.body)

                if let info = result.info, let desc = info.desc {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Status/Actions
            if result.isInstalled {
                installedBadge
            } else if isInstalling {
                installingIndicator
            } else if installSucceeded {
                successBadge
            } else if installFailed {
                failedBadge
            } else {
                installButton
            }
        }
        .padding(.horizontal)
        .padding(.vertical, LayoutConstants.compactPadding)
        .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            contextMenuContent
        }
    }

    // MARK: - Subviews

    /// Badge indicating the package is already installed.
    private var installedBadge: some View {
        Text("Installed")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, LayoutConstants.statusBadgeHorizontalPadding)
            .padding(.vertical, LayoutConstants.statusBadgeVerticalPadding)
            .background(.quaternary)
            .cornerRadius(4)
    }

    /// Progress indicator shown during installation.
    private var installingIndicator: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.7)
            Text("Installing...")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Badge shown after successful installation.
    private var successBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Installed")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Badge shown after failed installation.
    private var failedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text("Failed")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Button to initiate installation.
    private var installButton: some View {
        Button(action: onInstall) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                Text("Install")
            }
            .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    /// Context menu content.
    @ViewBuilder
    private var contextMenuContent: some View {
        Button("Show Details") {
            onShowInfo()
        }

        if !result.isInstalled && !isInstalling {
            Button("Install") {
                onInstall()
            }
        }
    }
}
