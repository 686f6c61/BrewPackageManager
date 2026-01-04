//
//  AccentGradient.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// The app's primary accent gradient for branding elements.
///
/// Provides a warm amber gradient (#FBB040) for headers, accent bars,
/// and progress indicators, establishing visual identity throughout the app.
enum AccentGradient {

    // MARK: - Colors

    /// Primary brand color (#FBB040) - Warm amber.
    static let brandColor = Color(red: 251/255, green: 176/255, blue: 64/255)

    /// The gradient color array with opacity variations for depth.
    static let colors: [Color] = [
        brandColor.opacity(0.8),
        brandColor,
        brandColor.opacity(0.8)
    ]

    // MARK: - Gradients

    /// A linear gradient for horizontal accent bars and headers.
    static var horizontal: LinearGradient {
        LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// A linear gradient for vertical elements.
    static var vertical: LinearGradient {
        LinearGradient(
            colors: colors,
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - ShapeStyle Extension

extension ShapeStyle where Self == LinearGradient {
    /// Convenience accessor for the app's accent gradient.
    ///
    /// Allows using `.accentGradient` directly with SwiftUI shape styles.
    static var accentGradient: LinearGradient {
        AccentGradient.horizontal
    }
}

#Preview {
    VStack(spacing: LayoutConstants.previewSpacing) {
        RoundedRectangle(cornerRadius: 4)
            .fill(.accentGradient)
            .frame(height: 4)
        
        RoundedRectangle(cornerRadius: 8)
            .fill(AccentGradient.vertical)
            .frame(width: 100, height: 100)
    }
    .padding()
}
