//
//  BrewPackageInfo.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

/// Detailed information about a package from `brew info --json=v2`.
///
/// This structure contains comprehensive metadata about a Homebrew package,
/// including version information, URLs, installation status, and licensing.
nonisolated struct BrewPackageInfo: Codable, Sendable, Equatable, Hashable {

    // MARK: - Basic Properties

    /// The short name of the package.
    let name: String

    /// The full qualified name including the tap.
    let fullName: String

    /// A brief description of what the package does.
    let desc: String?

    /// The URL to the package's homepage.
    let homepage: String?

    /// The software license (e.g., "MIT", "Apache-2.0").
    let license: String?

    // MARK: - Version and URL Information

    /// Version information for the package.
    let versions: Versions

    /// Source code URLs for the package.
    let urls: URLs?

    // MARK: - Installation Information

    /// All currently installed versions of this package.
    let installedVersions: [InstalledVersion]?

    /// The version currently linked in the Homebrew prefix (formulae only).
    let linkedKeg: String?

    /// Whether this package has an update available.
    let outdated: Bool?

    // MARK: - Nested Types

    /// Version information for a package.
    struct Versions: Codable, Sendable, Equatable, Hashable {
        /// The stable release version.
        let stable: String?

        /// The HEAD (development) version identifier.
        let head: String?

        /// Whether a bottle (precompiled binary) is available.
        let bottle: Bool?
    }

    /// Source code URLs for a package.
    struct URLs: Codable, Sendable, Equatable, Hashable {
        /// URL information for the stable release.
        let stable: StableURL?

        /// URL information for the HEAD (development) version.
        let head: HeadURL?

        /// Stable release URL information.
        struct StableURL: Codable, Sendable, Equatable, Hashable {
            /// The download URL for the stable release source code.
            let url: String?
        }

        /// HEAD (development) URL information.
        struct HeadURL: Codable, Sendable, Equatable, Hashable {
            /// The repository URL for the development version.
            let url: String?
        }
    }

    /// Information about an installed version of a package.
    struct InstalledVersion: Codable, Sendable, Equatable, Hashable {
        /// The version string (e.g., "1.2.3").
        let version: String

        /// Whether this version was explicitly requested by the user.
        let installedOnRequest: Bool?

        /// Whether this version was installed as a dependency.
        let installedAsDepency: Bool?

        enum CodingKeys: String, CodingKey {
            case version
            case installedOnRequest = "installed_on_request"
            case installedAsDepency = "installed_as_dependency"
        }
    }

    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case desc
        case homepage
        case license
        case versions
        case urls
        case installedVersions = "installed"
        case linkedKeg = "linked_keg"
        case outdated
    }

    // MARK: - Computed Properties

    /// GitHub repository URL if available.
    ///
    /// This property attempts to extract a GitHub URL from the package metadata
    /// by checking the homepage first, then falling back to the HEAD URL.
    ///
    /// - Returns: The GitHub repository URL, or `nil` if not available.
    var githubURL: URL? {
        // Check homepage first
        if let homepage, homepage.contains("github.com") {
            return URL(string: homepage)
        }
        // Fall back to checking HEAD URL
        if let headURL = urls?.head?.url, headURL.contains("github.com") {
            return URL(string: headURL)
        }
        return nil
    }

    /// Changelog/releases URL for GitHub repositories.
    ///
    /// This property constructs a URL to the GitHub releases page by transforming
    /// the repository URL. It handles trailing slashes and .git suffixes.
    ///
    /// - Returns: The GitHub releases page URL, or `nil` if not a GitHub repository.
    var changelogURL: URL? {
        guard let githubURL else { return nil }

        // Convert https://github.com/user/repo to releases page
        var components = URLComponents(url: githubURL, resolvingAgainstBaseURL: false)
        guard var path = components?.path else { return nil }

        // Remove trailing slash if present
        if path.hasSuffix("/") {
            path.removeLast()
        }

        // Remove .git suffix if present
        if path.hasSuffix(".git") {
            path = String(path.dropLast(4))
        }

        components?.path = path + "/releases"
        return components?.url
    }
}
