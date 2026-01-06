//
//  BrewPackagesArgumentsBuilder.swift
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

/// Builds command-line argument arrays for Homebrew commands.
///
/// This utility provides static methods that construct the proper arguments
/// for various brew commands, ensuring consistent formatting and options.
nonisolated enum BrewPackagesArgumentsBuilder {

    // MARK: - Public Methods

    /// Builds arguments for listing all installed packages.
    ///
    /// - Parameters:
    ///   - type: Optional package type filter (currently unused).
    ///   - debugMode: Whether to include debug output.
    /// - Returns: Argument array for `brew info --json=v2 --installed`.
    static func listInstalledArguments(type: PackageType?, debugMode: Bool) -> [String] {
        var arguments = ["info", "--json=v2", "--installed"]
        if debugMode {
            arguments.append("--debug")
        }
        return arguments
    }

    /// Builds arguments for checking outdated packages.
    ///
    /// - Parameter debugMode: Whether to include debug output.
    /// - Returns: Argument array for `brew outdated --json=v2`.
    static func outdatedArguments(debugMode: Bool) -> [String] {
        var arguments = ["outdated", "--json=v2"]
        if debugMode {
            arguments.append("--debug")
        }
        return arguments
    }

    /// Builds arguments for getting detailed info about a specific package.
    ///
    /// - Parameters:
    ///   - packageName: The name of the package to query.
    ///   - debugMode: Whether to include debug output.
    /// - Returns: Argument array for `brew info --json=v2 <package>`.
    static func infoArguments(packageName: String, debugMode: Bool) -> [String] {
        var arguments = ["info", "--json=v2", packageName]
        if debugMode {
            arguments.append("--debug")
        }
        return arguments
    }

    /// Builds arguments for upgrading a specific package.
    ///
    /// - Parameters:
    ///   - packageName: The name of the package to upgrade.
    ///   - debugMode: Whether to include debug output.
    /// - Returns: Argument array for `brew upgrade <package>`.
    static func upgradePackageArguments(packageName: String, debugMode: Bool) -> [String] {
        var arguments = ["upgrade", packageName]
        if debugMode {
            arguments.append("--debug")
        }
        return arguments
    }

    /// Builds arguments for upgrading all outdated packages.
    ///
    /// - Parameter debugMode: Whether to include debug output.
    /// - Returns: Argument array for `brew upgrade`.
    static func upgradeAllArguments(debugMode: Bool) -> [String] {
        var arguments = ["upgrade"]
        if debugMode {
            arguments.append("--debug")
        }
        return arguments
    }

    /// Builds arguments for uninstalling a specific package.
    ///
    /// - Parameters:
    ///   - packageName: The name of the package to uninstall.
    ///   - debugMode: Whether to include debug output.
    /// - Returns: Argument array for `brew uninstall <package>`.
    static func uninstallPackageArguments(packageName: String, debugMode: Bool) -> [String] {
        var arguments = ["uninstall", packageName]
        if debugMode {
            arguments.append("--debug")
        }
        return arguments
    }

    /// Builds arguments for searching packages.
    ///
    /// - Parameters:
    ///   - query: The search term.
    ///   - type: Optional package type filter (formula or cask).
    ///   - debugMode: Whether to include debug output.
    /// - Returns: Argument array for `brew search [--formula|--cask] <query>`.
    static func searchArguments(query: String, type: PackageType?, debugMode: Bool) -> [String] {
        var arguments = ["search"]

        // Add type filter if specified
        if let type = type {
            switch type {
            case .formula:
                arguments.append("--formula")
            case .cask:
                arguments.append("--cask")
            }
        }

        arguments.append(query)

        if debugMode {
            arguments.append("--debug")
        }

        return arguments
    }

    /// Builds arguments for installing a package.
    ///
    /// - Parameters:
    ///   - packageName: The name of the package to install.
    ///   - type: The package type (formula or cask).
    ///   - debugMode: Whether to include debug output.
    /// - Returns: Argument array for `brew install [--cask] <package>`.
    static func installPackageArguments(packageName: String, type: PackageType, debugMode: Bool) -> [String] {
        var arguments = ["install"]

        // Casks require the --cask flag
        if type == .cask {
            arguments.append("--cask")
        }

        arguments.append(packageName)

        if debugMode {
            arguments.append("--debug")
        }

        return arguments
    }
}
