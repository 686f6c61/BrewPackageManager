//
//  HoverHighlightModifier.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// A view modifier that adds a subtle highlight effect on hover.
///
/// This modifier provides visual feedback when the user hovers over interactive
/// elements by applying a slight background tint and scale effect.
struct HoverHighlightModifier: ViewModifier {

    /// Whether the hover effect is enabled.
    let isEnabled: Bool

    /// Tracks whether the mouse is currently hovering over the view.
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(isEnabled && isHovered ? Color.primary.opacity(0.08) : Color.clear)
            .clipShape(.rect(cornerRadius: LayoutConstants.hoverCornerRadius))
            .scaleEffect(isEnabled && isHovered ? 1.0 : LayoutConstants.hoverScaleEffect)
            .onHover {
                if isEnabled {
                    isHovered = $0
                } else {
                    isHovered = false
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - View Extension

extension View {
    /// Adds a subtle highlight effect when the view is hovered.
    ///
    /// - Parameter isEnabled: Whether the hover effect is enabled. Defaults to `true`.
    /// - Returns: A view with the hover highlight applied.
    func hoverHighlight(isEnabled: Bool = true) -> some View {
        modifier(HoverHighlightModifier(isEnabled: isEnabled))
    }
}

#Preview {
    VStack {
        Text("Hover over me")
            .padding()
            .hoverHighlight()
        
        Text("Also hover here")
            .padding()
            .hoverHighlight()
    }
    .padding()
}
