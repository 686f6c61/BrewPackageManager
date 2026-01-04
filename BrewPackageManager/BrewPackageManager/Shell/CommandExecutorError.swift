//
//  CommandExecutorError.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

/// Errors that can occur during command execution.
///
/// This enum represents the different failure modes that can occur when executing
/// shell commands via `CommandExecutor`.
nonisolated enum CommandExecutorError: Error {

    // MARK: - Error Cases

    /// The command execution exceeded the specified timeout duration.
    ///
    /// When this error occurs, the process has been automatically terminated.
    case timedOut
}
