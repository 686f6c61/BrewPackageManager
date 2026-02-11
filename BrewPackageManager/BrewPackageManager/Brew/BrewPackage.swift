//
//  BrewPackage.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

/// Represents a Homebrew package (formula or cask).
///
/// This structure provides a unified representation for both formulae (command-line tools)
/// and casks (GUI applications), including version information, update status, and metadata.
nonisolated struct BrewPackage: Codable, Identifiable, Sendable, Hashable {

    // MARK: - Basic Properties

    /// The short name of the package.
    let name: String

    /// The full qualified name including the tap.
    let fullName: String

    /// A brief description of what the package does.
    let desc: String?

    /// The URL to the package's homepage.
    let homepage: String?

    /// Whether this is a formula (command-line tool) or cask (GUI app).
    let type: PackageType

    // MARK: - Version Information

    /// The currently installed version.
    let installedVersion: String

    /// The latest available version, if known.
    let currentVersion: String?

    // MARK: - Update Status

    /// Whether this package has an update available.
    var isOutdated: Bool

    /// The version this package is pinned to, if any.
    /// Pinned packages will not be upgraded automatically.
    let pinnedVersion: String?

    // MARK: - Additional Metadata

    /// The Homebrew tap this package comes from (e.g., "homebrew/core").
    let tap: String?

    // MARK: - Computed Properties

    /// Unique identifier for SwiftUI list rendering.
    var id: String { "\(type.rawValue):\(fullName)" }

    /// The name to display in the UI.
    var displayName: String { name }

    /// Whether this package has an update available with a known version.
    var hasUpdate: Bool {
        isOutdated && currentVersion != nil
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case desc
        case homepage
        case type
        case installedVersion = "installed_version"
        case currentVersion = "current_version"
        case isOutdated = "outdated"
        case pinnedVersion = "pinned_version"
        case tap
    }
}
