//
//  PackageType.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

/// Represents the two types of Homebrew packages.
///
/// Homebrew distinguishes between:
/// - `formula`: Command-line tools and libraries
/// - `cask`: GUI applications
///
/// Each type has associated display metadata (label and system icon).
nonisolated enum PackageType: String, Codable, Sendable, CaseIterable {
    /// A Homebrew formula (command-line tool or library).
    case formula

    /// A Homebrew cask (GUI application).
    case cask

    // MARK: - Computed Properties

    /// The display label for this package type.
    var label: String {
        switch self {
        case .formula:
            "Formula"
        case .cask:
            "Cask"
        }
    }

    /// The SF Symbol name for this package type.
    var systemImage: String {
        switch self {
        case .formula:
            "cube.box"
        case .cask:
            "app.dashed"
        }
    }
}
