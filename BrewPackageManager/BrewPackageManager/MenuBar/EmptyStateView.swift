//
//  EmptyStateView.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// The empty state view displayed when no packages match the current filter.
///
/// This view appears when:
/// - All packages are up to date (when "Outdated only" is enabled)
/// - The package list is empty but loaded successfully
///
/// Displays a checkmark icon with "All packages up to date" message.
struct EmptyStateView: View {

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("All packages up to date")
                .font(.headline)

            Text("No updates available")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
