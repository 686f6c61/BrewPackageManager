//
//  HelpScreen.swift
//  BrewPackageManager
//
//  Enlaces de soporte, documentación y versiones.
//

import SwiftUI

struct HelpScreen: View {
    private var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "–"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                SectionHeader(title: "Help", detail: "Links that matter, plain language.")
                VStack(alignment: .leading, spacing: 10) {
                    InfoRow(label: "Author", value: "686f6c61")
                    InfoRow(label: "Current version", value: currentVersion)
                }
                .card()
                LinkRow(title: "Repository", subtitle: "Open the GitHub repository", urlString: "https://github.com/686f6c61/BrewPackageManager")
                LinkRow(title: "Author", subtitle: "Open the author profile on GitHub", urlString: "https://github.com/686f6c61")
                LinkRow(title: "Changelog", subtitle: "Everything that changed between releases", urlString: "https://github.com/686f6c61/BrewPackageManager/blob/main/CHANGELOG.md")
                LinkRow(title: "Releases", subtitle: "Latest DMG and release notes", urlString: "https://github.com/686f6c61/BrewPackageManager/releases")
                LinkRow(title: "Homebrew", subtitle: "Official Homebrew documentation", urlString: "https://brew.sh")
            }
            .padding(AppTheme.pagePadding)
        }
        .navigationTitle("Help")
    }
}
