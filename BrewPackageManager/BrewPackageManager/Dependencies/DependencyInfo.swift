//
//  DependencyInfo.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//  Version: 1.7.0
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

/// Information about package dependencies.
///
/// Represents a package and all its dependencies (direct and transitive).
struct DependencyInfo: Identifiable, Sendable, Hashable {

    /// Unique identifier (package name).
    let id: String

    /// The package name.
    let packageName: String

    /// Direct dependencies of this package.
    let dependencies: [String]

    /// Optional dependencies (not required for installation).
    let optionalDependencies: [String]

    /// Build-only dependencies (needed only during compilation).
    let buildDependencies: [String]

    /// Whether this package is a dependency of another package.
    let isUsedBy: [String]

    /// Total dependency count (excluding optionals and build deps).
    nonisolated var dependencyCount: Int {
        dependencies.count
    }

    /// Whether this package has any dependencies.
    var hasDependencies: Bool {
        !dependencies.isEmpty
    }

    /// Whether this package is used by other packages.
    var isRequired: Bool {
        !isUsedBy.isEmpty
    }
}

extension DependencyInfo {

    /// Parse dependency information from brew info JSON output.
    nonisolated static func parse(from json: [String: Any]) -> DependencyInfo? {
        guard let name = json["name"] as? String else { return nil }

        let dependencies = json["dependencies"] as? [String] ?? []
        let optionalDeps = json["optional_dependencies"] as? [String] ?? []
        let buildDeps = json["build_dependencies"] as? [String] ?? []
        let usedBy = json["used_by"] as? [String] ?? []

        return DependencyInfo(
            id: name,
            packageName: name,
            dependencies: dependencies,
            optionalDependencies: optionalDeps,
            buildDependencies: buildDeps,
            isUsedBy: usedBy
        )
    }

    /// Create an empty dependency info for a package with no dependencies.
    nonisolated static func empty(packageName: String) -> DependencyInfo {
        DependencyInfo(
            id: packageName,
            packageName: packageName,
            dependencies: [],
            optionalDependencies: [],
            buildDependencies: [],
            isUsedBy: []
        )
    }
}
