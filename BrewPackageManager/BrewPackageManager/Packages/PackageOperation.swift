//
//  PackageOperation.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

/// Represents the state of an operation on a package.
///
/// This structure tracks the status, any error that occurred, and diagnostic
/// information for operations like upgrades and uninstalls.
nonisolated struct PackageOperation: Sendable {

    // MARK: - Properties

    /// The current status of the operation.
    let status: PackageOperationStatus

    /// The error that occurred, if the operation failed.
    let error: AppError?

    /// Optional diagnostic information about the operation.
    let diagnostics: String?

    // MARK: - Static Instances

    /// A default idle operation with no error or diagnostics.
    static let idle = PackageOperation(status: .idle, error: nil, diagnostics: nil)
}
