//
//  SectionContainerModifier.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// A view modifier that styles content as a distinct section container.
///
/// This modifier provides consistent styling for grouped content sections,
/// applying a material background with rounded corners and horizontal padding.
struct SectionContainerModifier: ViewModifier {

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: .rect(cornerRadius: LayoutConstants.sectionContainerCornerRadius))
            .padding(.horizontal, LayoutConstants.sectionContainerHorizontalPadding)
    }
}

// MARK: - View Extension

extension View {
    /// Applies section container styling with material background and padding.
    ///
    /// - Returns: A view styled as a section container.
    func sectionContainer() -> some View {
        modifier(SectionContainerModifier())
    }
}

#Preview {
    VStack {
        VStack {
            Text("Section Content")
            Text("More content")
        }
        .padding()
        .sectionContainer()
    }
    .padding()
    .frame(width: LayoutConstants.previewSectionWidth)
}
