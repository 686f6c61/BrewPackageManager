//
//  MenuSectionLabel.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// A small section header label for visual grouping in the menu.
///
/// This view provides a consistent style for section headers in menu lists,
/// displaying uppercase text with secondary styling and appropriate padding.
/// Commonly used to separate different groups of menu items.
struct MenuSectionLabel: View {

    // MARK: - Properties

    /// The localized text to display as the section header.
    let title: LocalizedStringKey

    // MARK: - Body

    var body: some View {
        Text(title)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal)
            .padding(.top, LayoutConstants.sectionLabelTopPadding)
            .padding(.bottom, LayoutConstants.sectionLabelBottomPadding)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: .zero) {
        MenuSectionLabel(title: "Services")
        Text("Service 1").padding(.horizontal)
        Text("Service 2").padding(.horizontal)
        
        MenuSectionLabel(title: "Actions")
        Text("Start All").padding(.horizontal)
        Text("Stop All").padding(.horizontal)
    }
    .frame(width: 250)
}
