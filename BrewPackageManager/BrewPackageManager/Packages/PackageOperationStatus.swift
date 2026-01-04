//
//  PackageOperationStatus.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

/// The status of a package operation (upgrade or uninstall).
///
/// This enum tracks the lifecycle of operations performed on individual packages.
nonisolated enum PackageOperationStatus: Sendable {

    // MARK: - Status Cases

    /// No operation is currently running on this package.
    case idle

    /// An operation is currently in progress.
    case running

    /// The operation completed successfully.
    case succeeded

    /// The operation failed with an error.
    case failed
}
