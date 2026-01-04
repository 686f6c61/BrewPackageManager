//
//  PanelSectionCardView.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// A card container for grouping related content in panel views.
///
/// This generic view wraps content with:
/// - Section title (caption style, secondary color)
/// - Optional subtitle for additional context
/// - Container styling via `sectionContainer()` modifier
/// - Consistent padding and alignment
///
/// Used extensively in Settings and other panel views to organize controls
/// into visually distinct sections.
struct PanelSectionCardView<Content: View>: View {

    // MARK: - Properties

    /// The section title displayed at the top of the card.
    let title: LocalizedStringKey

    /// Optional subtitle text for additional context.
    let subtitle: LocalizedStringKey?

    /// The content to display within the card section.
    @ViewBuilder let content: () -> Content

    // MARK: - Initialization

    /// Creates a new panel section card.
    ///
    /// - Parameters:
    ///   - title: The section title to display.
    ///   - subtitle: Optional subtitle text. Defaults to `nil`.
    ///   - content: A view builder for the card's content.
    init(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutConstants.compactSpacing) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(.horizontal, LayoutConstants.headerVerticalPadding)
        .padding(.vertical, LayoutConstants.compactPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sectionContainer()
    }
}
