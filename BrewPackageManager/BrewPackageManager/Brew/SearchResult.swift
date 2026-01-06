//
//  SearchResult.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//  Version: 1.5.0
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

/// Represents a package search result from Homebrew.
///
/// This structure holds information about a package found through search,
/// including its type (formula or cask), installation status, and optionally
/// cached detailed information.
///
/// The `id` property uniquely identifies the result by combining the package
/// type and name, ensuring proper list rendering in SwiftUI.
nonisolated struct SearchResult: Identifiable, Sendable, Hashable {

    // MARK: - Properties

    /// Unique identifier combining type and name (e.g., "formula:python").
    let id: String

    /// The package name (e.g., "python", "visual-studio-code").
    let name: String

    /// The package type (formula or cask).
    let type: PackageType

    /// Whether this package is already installed on the system.
    let isInstalled: Bool

    /// Cached detailed package information, if fetched.
    ///
    /// This property is initially `nil` and populated when the user requests
    /// more information about the search result.
    var info: BrewPackageInfo?

    // MARK: - Initialization

    /// Creates a new search result.
    ///
    /// - Parameters:
    ///   - name: The package name.
    ///   - type: The package type (formula or cask).
    ///   - isInstalled: Whether the package is currently installed.
    init(name: String, type: PackageType, isInstalled: Bool) {
        self.id = "\(type.rawValue):\(name)"
        self.name = name
        self.type = type
        self.isInstalled = isInstalled
        self.info = nil
    }
}
