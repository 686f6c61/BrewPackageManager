//
//  CommandResult.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

/// Contains the result of executing a shell command.
///
/// This structure encapsulates all information about a command execution,
/// including the command itself, its output, exit status, and metadata.
/// All properties are thread-safe and conform to `Sendable` for use in
/// concurrent contexts.
nonisolated struct CommandResult: Sendable {

    // MARK: - Properties

    /// The file path of the executable that was run.
    let executablePath: String

    /// The command-line arguments passed to the executable.
    let arguments: [String]

    /// The standard output (stdout) captured from the command.
    let stdout: String

    /// The standard error (stderr) captured from the command.
    let stderr: String

    /// The exit code returned by the command.
    ///
    /// By convention, 0 indicates success and non-zero indicates an error.
    let exitCode: Int32

    /// Whether the command was cancelled via task cancellation.
    let wasCancelled: Bool

    /// The total duration of the command execution.
    let duration: Duration

    // MARK: - Computed Properties

    /// Whether the command completed successfully.
    ///
    /// A command is considered successful if it:
    /// - Exited with code 0
    /// - Was not cancelled
    var isSuccess: Bool {
        exitCode == 0 && !wasCancelled
    }
}
