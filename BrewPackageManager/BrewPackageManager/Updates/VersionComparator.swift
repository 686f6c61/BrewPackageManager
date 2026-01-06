//
//  VersionComparator.swift
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

/// Semantic version comparison utility.
///
/// Compares version strings in the format "X.Y.Z" where X, Y, Z are integers.
/// Supports optional patch version (e.g., "1.5" is treated as "1.5.0").
nonisolated enum VersionComparator {

    // MARK: - Methods

    /// Compares two semantic version strings.
    ///
    /// - Parameters:
    ///   - current: The current version string (e.g., "1.5.0")
    ///   - latest: The latest available version string (e.g., "1.6.0")
    /// - Returns: `true` if `latest` is newer than `current`, `false` otherwise.
    /// - Throws: `AppError.invalidVersionFormat` if either version is malformed.
    static func isNewerVersion(current: String, latest: String) throws -> Bool {
        let currentComponents = try parseVersion(current)
        let latestComponents = try parseVersion(latest)

        // Compare major version
        if latestComponents.major > currentComponents.major {
            return true
        } else if latestComponents.major < currentComponents.major {
            return false
        }

        // Compare minor version
        if latestComponents.minor > currentComponents.minor {
            return true
        } else if latestComponents.minor < currentComponents.minor {
            return false
        }

        // Compare patch version
        return latestComponents.patch > currentComponents.patch
    }

    /// Parses a semantic version string into components.
    ///
    /// - Parameter version: Version string (e.g., "1.5.0" or "1.5")
    /// - Returns: Tuple of (major, minor, patch) integers
    /// - Throws: `AppError.invalidVersionFormat` if version is malformed
    private static func parseVersion(_ version: String) throws -> (major: Int, minor: Int, patch: Int) {
        let components = version.split(separator: ".").compactMap { Int($0) }

        guard components.count >= 2 else {
            throw AppError.invalidVersionFormat(version: version)
        }

        let major = components[0]
        let minor = components[1]
        let patch = components.count > 2 ? components[2] : 0

        return (major, minor, patch)
    }
}
