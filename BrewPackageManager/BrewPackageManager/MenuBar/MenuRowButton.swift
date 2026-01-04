//
//  MenuRowButton.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// A reusable button for menu row items.
///
/// This view provides a consistent style for menu buttons with:
/// - SF Symbol icon on the left
/// - Title text
/// - Optional disclosure chevron on the right
/// - Hover highlight effect (when enabled)
/// - Disabled state support
///
/// Used throughout the menu for actions like Refresh, Settings, Help, Quit.
struct MenuRowButton: View {

    // MARK: - Properties

    /// The button title text.
    let title: LocalizedStringKey

    /// The SF Symbol name for the button icon.
    let systemImage: String

    /// Whether the button is enabled (affects hover and disabled state).
    let isEnabled: Bool

    /// Whether to show a disclosure chevron on the right side.
    let showDisclosure: Bool

    /// The action to perform when the button is tapped.
    let action: () -> Void

    // MARK: - Initialization

    /// Creates a new menu row button.
    ///
    /// - Parameters:
    ///   - title: The button title text.
    ///   - systemImage: The SF Symbol name for the icon.
    ///   - isEnabled: Whether the button is enabled. Defaults to `true`.
    ///   - showDisclosure: Whether to show a disclosure chevron. Defaults to `false`.
    ///   - action: The action to perform when tapped.
    init(
        _ title: LocalizedStringKey,
        systemImage: String,
        isEnabled: Bool = true,
        showDisclosure: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.showDisclosure = showDisclosure
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: LayoutConstants.menuRowIconWidth)

                Text(title)
                
                Spacer()
                
                if showDisclosure {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, LayoutConstants.compactPadding)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .hoverHighlight(isEnabled: isEnabled)
        .disabled(!isEnabled)
    }
}
