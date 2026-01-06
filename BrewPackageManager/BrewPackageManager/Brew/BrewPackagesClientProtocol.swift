//
//  BrewPackagesClientProtocol.swift
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

/// Protocol defining the interface for Homebrew package operations.
///
/// This protocol must be implemented by actors to ensure thread-safe execution
/// of Homebrew commands. All methods are asynchronous and can throw errors.
protocol BrewPackagesClientProtocol: Actor {

    /// Lists all packages installed via Homebrew.
    func listInstalledPackages(debugMode: Bool) async throws -> [BrewPackage]

    /// Lists the names of all outdated packages.
    func listOutdatedPackages(debugMode: Bool) async throws -> [String]

    /// Retrieves detailed information about a specific package.
    func getPackageInfo(_ packageName: String, debugMode: Bool) async throws -> BrewPackageInfo

    /// Upgrades a specific package to its latest version.
    func upgradePackage(_ packageName: String, debugMode: Bool) async throws

    /// Upgrades all outdated packages to their latest versions.
    func upgradeAllPackages(debugMode: Bool) async throws

    /// Uninstalls a specific package.
    func uninstallPackage(_ packageName: String, debugMode: Bool) async throws

    /// Searches for packages matching the given query.
    ///
    /// - Parameters:
    ///   - query: The search term to query.
    ///   - type: Optional package type filter (formula or cask).
    ///   - debugMode: Whether to run in debug mode.
    /// - Returns: Array of package names matching the search.
    func searchPackages(_ query: String, type: PackageType?, debugMode: Bool) async throws -> [String]

    /// Installs a package.
    ///
    /// - Parameters:
    ///   - packageName: The name of the package to install.
    ///   - type: The package type (formula or cask).
    ///   - debugMode: Whether to run in debug mode.
    func installPackage(_ packageName: String, type: PackageType, debugMode: Bool) async throws
}
