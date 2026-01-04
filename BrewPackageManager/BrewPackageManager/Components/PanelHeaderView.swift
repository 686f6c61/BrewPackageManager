//
//  PanelHeaderView.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// Reusable header for overlay panels (Settings, Package Info, etc.).
///
/// This view provides a consistent header design for panel views with:
/// - Back button for navigation
/// - Panel title
/// - Horizontal and vertical padding
///
/// Used across Settings, Package Info, and other detail views.
struct PanelHeaderView: View {

    // MARK: - Properties

    /// The title text to display in the header.
    let title: String

    /// Callback invoked when the back button is tapped.
    let onBack: () -> Void

    // MARK: - Body

    var body: some View {
        HStack {
            Button("Back", systemImage: "chevron.left") {
                onBack()
            }
            .labelStyle(.iconOnly)
            .font(.body)
            .buttonStyle(.plain)
            
            Text(title)
                .font(.headline)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, LayoutConstants.headerVerticalPadding)
    }
}

#Preview {
    VStack(spacing: .zero) {
        PanelHeaderView(title: "Settings") { }
        Divider()
        Spacer()
    }
    .frame(width: LayoutConstants.menuWidth, height: LayoutConstants.previewPanelHeight)
}
