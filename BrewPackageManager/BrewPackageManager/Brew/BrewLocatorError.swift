//
//  BrewLocatorError.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

/// Errors that can occur when locating Homebrew.
///
/// This enum provides localized error descriptions to help users understand
/// why Homebrew couldn't be found on their system.
nonisolated enum BrewLocatorError: Error, LocalizedError {

    // MARK: - Error Cases

    /// Homebrew executable could not be found on the system.
    ///
    /// This error occurs when Homebrew is not installed or is installed in a
    /// non-standard location that wasn't checked by the locator.
    case brewNotFound

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .brewNotFound:
            "Homebrew is not installed or could not be found. Please install Homebrew from https://brew.sh"
        }
    }
}
