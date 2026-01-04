//
//  GlassBackgroundModifier.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// A view modifier that applies version-appropriate glass/material backgrounds.
///
/// This modifier provides a modern glass effect on macOS 26+ using Liquid Glass,
/// and gracefully falls back to ultra-thin material on earlier macOS versions.
struct GlassBackgroundModifier: ViewModifier {

    /// The corner radius for the background shape.
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            content.background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies a glass background effect appropriate for the current macOS version.
    ///
    /// - Parameter cornerRadius: The corner radius for the background shape. Defaults to `LayoutConstants.glassCornerRadius`.
    /// - Returns: A view with the glass background applied.
    func glassBackground(cornerRadius: CGFloat = LayoutConstants.glassCornerRadius) -> some View {
        modifier(GlassBackgroundModifier(cornerRadius: cornerRadius))
    }
}

#Preview {
    VStack {
        Text("Glass Background")
            .padding()
            .glassBackground()
    }
    .padding()
    .frame(width: LayoutConstants.previewGlassWidth, height: LayoutConstants.previewGlassHeight)
}

