//
//  ReleaseInfo.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//  Version: 1.6.0
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

/// GitHub release information from the releases API.
///
/// Decoded from: https://api.github.com/repos/{owner}/{repo}/releases/latest
nonisolated struct ReleaseInfo: Decodable, Sendable {

    // MARK: - Properties

    /// The git tag name (e.g., "v1.6.0")
    let tagName: String

    /// Human-readable release name/title
    let name: String

    /// Release notes in markdown format
    let body: String

    /// URL to the GitHub release page
    let htmlUrl: String

    /// Whether this is a prerelease
    let prerelease: Bool

    /// Whether this is a draft (shouldn't happen for /latest endpoint)
    let draft: Bool

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case prerelease
        case draft
    }

    // MARK: - Computed Properties

    /// Extract semantic version from tag name (removes "v" prefix)
    var version: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }
}
