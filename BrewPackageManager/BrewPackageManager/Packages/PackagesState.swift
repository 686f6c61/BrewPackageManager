//
//  PackagesState.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

/// The loading state of the packages list.
///
/// This enum represents the different states of the package list as it's
/// loaded, refreshed, or encounters errors.
nonisolated enum PackagesState: Sendable {

    // MARK: - State Cases

    /// Initial state before any packages have been loaded.
    case idle

    /// Currently loading packages for the first time.
    case loading

    /// Packages have been loaded successfully.
    case loaded([BrewPackage])

    /// Refreshing the package list while showing existing packages.
    case refreshing([BrewPackage])

    /// An error occurred while loading or refreshing.
    case error(AppError)
}
