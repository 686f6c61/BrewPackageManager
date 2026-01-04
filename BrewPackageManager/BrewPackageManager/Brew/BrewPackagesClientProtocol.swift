//
//  BrewPackagesClientProtocol.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
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
}
