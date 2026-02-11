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

/// Persisted diagnostics for the most recently executed shell command.
///
/// This captures enough metadata to support post-mortem debugging when
/// command execution fails, times out, is cancelled, or produces huge output.
nonisolated struct CommandExecutionDiagnostics: Codable, Sendable {

    /// Timestamp when diagnostics were recorded.
    let timestamp: Date

    /// Executable path used for the command.
    let executablePath: String

    /// Command arguments.
    let arguments: [String]

    /// Exit code from the process, if available.
    let exitCode: Int32?

    /// Whether the command was cancelled.
    let wasCancelled: Bool

    /// Whether the command timed out.
    let timedOut: Bool

    /// Total command duration in seconds.
    let durationSeconds: Double

    /// Total stdout bytes produced by the process.
    let stdoutBytesTotal: Int

    /// Total stderr bytes produced by the process.
    let stderrBytesTotal: Int

    /// Stdout bytes retained in memory.
    let stdoutBytesCaptured: Int

    /// Stderr bytes retained in memory.
    let stderrBytesCaptured: Int

    /// Whether stdout output was truncated.
    let stdoutTruncated: Bool

    /// Whether stderr output was truncated.
    let stderrTruncated: Bool

    /// Capture limit used by the command, if any.
    let captureLimitBytes: Int?

    /// Error message when the process failed to launch.
    let launchError: String?

    /// Human-readable command line.
    var commandLine: String {
        ([executablePath] + arguments).joined(separator: " ")
    }

    /// Human-readable status summary.
    var statusSummary: String {
        if timedOut {
            return "Timed out"
        }

        if wasCancelled {
            return "Cancelled"
        }

        if let launchError {
            return "Launch error: \(launchError)"
        }

        if let exitCode {
            return exitCode == 0 ? "Success" : "Exit code \(exitCode)"
        }

        return "Unknown"
    }

    /// Text blob suitable for clipboard sharing.
    var reportText: String {
        """
        Time: \(timestamp)
        Status: \(statusSummary)
        Command: \(commandLine)
        Duration: \(String(format: "%.2f", durationSeconds))s
        Exit code: \(exitCode.map(String.init) ?? "n/a")
        Timed out: \(timedOut)
        Cancelled: \(wasCancelled)
        Capture limit: \(captureLimitBytes.map(String.init) ?? "unlimited")
        Stdout bytes: \(stdoutBytesCaptured)/\(stdoutBytesTotal) captured\(stdoutTruncated ? " (truncated)" : "")
        Stderr bytes: \(stderrBytesCaptured)/\(stderrBytesTotal) captured\(stderrTruncated ? " (truncated)" : "")
        """
    }
}

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

    /// Whether the command timed out.
    let timedOut: Bool

    /// Whether stdout output was truncated due to capture limits.
    let stdoutTruncated: Bool

    /// Whether stderr output was truncated due to capture limits.
    let stderrTruncated: Bool

    /// Total stdout bytes produced (captured + truncated).
    let stdoutBytesTotal: Int

    /// Total stderr bytes produced (captured + truncated).
    let stderrBytesTotal: Int

    /// The total duration of the command execution.
    let duration: Duration

    // MARK: - Computed Properties

    /// Whether the command completed successfully.
    ///
    /// A command is considered successful if it:
    /// - Exited with code 0
    /// - Was not cancelled
    /// - Did not time out
    var isSuccess: Bool {
        exitCode == 0 && !wasCancelled && !timedOut
    }
}
