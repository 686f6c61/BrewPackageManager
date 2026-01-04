//
//  AppError.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

/// Domain-specific errors that can occur in the application.
///
/// This enum provides localized error descriptions and recovery suggestions
/// for all error conditions encountered during package management operations.
nonisolated enum AppError: Error, LocalizedError, Sendable {

    // MARK: - Error Cases

    /// Homebrew executable could not be found on the system.
    case brewNotFound

    /// A Homebrew command failed with a non-zero exit code.
    case brewFailed(exitCode: Int32, stderr: String)

    /// Failed to decode JSON output from a Homebrew command.
    case jsonDecodingFailed(rawOutput: String, underlyingErrorDescription: String)

    /// A command exceeded its timeout duration.
    case commandTimedOut

    /// The operation was cancelled by the user or system.
    case cancelled

    // MARK: - LocalizedError
    
    var errorDescription: String? {
        switch self {
        case .brewNotFound:
            "Homebrew is not installed or could not be found."
        case .brewFailed(let exitCode, let stderr):
            "Homebrew command failed (exit \(exitCode)): \(stderr)"
        case .jsonDecodingFailed(_, let description):
            "Failed to parse Homebrew output: \(description)"
        case .commandTimedOut:
            "The command timed out."
        case .cancelled:
            "The operation was cancelled."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .brewNotFound:
            "Install Homebrew from https://brew.sh"
        case .brewFailed:
            "Check that the service exists and try again."
        case .jsonDecodingFailed:
            "Try enabling Debug mode or run the command in Terminal to see the raw output."
        case .commandTimedOut:
            "Try the operation again or check if Homebrew is responding."
        case .cancelled:
            nil
        }
    }
}
