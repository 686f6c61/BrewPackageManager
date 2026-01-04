//
//  MenuBarHeaderView.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// The header view for the main menu bar interface.
///
/// Displays:
/// - App title ("Brew Package Manager")
/// - Updates badge showing count of outdated packages (when > 0)
///
/// The badge has an orange gradient background with white text.
struct MenuBarHeaderView: View {

    // MARK: - Environment

    /// The main packages store.
    @Environment(PackagesStore.self) private var store

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            HStack {
                Text("Brew Package Manager")
                    .font(.headline)

                Spacer()

                // Updates badge
                if store.outdatedCount > 0 {
                    Text("\(store.outdatedCount)")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.gradient, in: .capsule)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
}
