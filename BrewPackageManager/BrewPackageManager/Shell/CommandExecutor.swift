//
//  CommandExecutor.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

@preconcurrency import Foundation
import os

/// A utility that executes shell commands and captures their output.
///
/// This enum provides static methods to run executables asynchronously with proper
/// handling of stdout, stderr, timeouts, and cancellation. All command execution
/// is performed asynchronously using Swift's structured concurrency.
///
/// The executor handles:
/// - Asynchronous pipe reading to prevent deadlocks with large outputs
/// - Task cancellation with proper cleanup
/// - Timeout support with automatic process termination
/// - Thread-safe state management using locks
/// - Environment variable merging
///
/// Example usage:
/// ```swift
/// let result = try await CommandExecutor.run(
///     URL(filePath: "/usr/bin/brew"),
///     arguments: ["list"],
///     timeout: .seconds(30)
/// )
/// if result.isSuccess {
///     print(result.stdout)
/// }
/// ```
nonisolated enum CommandExecutor {

    // MARK: - Diagnostics

    /// Logger for command executor and diagnostics persistence.
    private static let logger = Logger(subsystem: "BrewPackageManager", category: "CommandExecutor")

    /// UserDefaults key for last command diagnostics.
    private static let diagnosticsDefaultsKey = "brewPackageManager.lastCommandDiagnostics"

    /// Loads diagnostics for the most recently executed command.
    static func loadLastDiagnostics(defaults: UserDefaults = .standard) -> CommandExecutionDiagnostics? {
        guard let data = defaults.data(forKey: diagnosticsDefaultsKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(CommandExecutionDiagnostics.self, from: data)
        } catch {
            logger.error("Failed to decode last command diagnostics: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Public Methods

    /// Runs the executable at the given URL with the specified arguments.
    ///
    /// This method executes a command asynchronously and captures both stdout and stderr.
    /// The command can be cancelled via task cancellation or terminated automatically
    /// after a timeout period. Pipe reading is performed asynchronously to prevent
    /// deadlocks when dealing with large command outputs.
    ///
    /// - Parameters:
    ///   - executableURL: The URL of the executable to run.
    ///   - arguments: The command-line arguments to pass to the executable.
    ///   - environment: Optional environment variables to merge with the current process environment.
    ///   - timeout: Optional timeout duration. If the command doesn't complete within this time, it will be terminated.
    ///   - captureLimitBytes: Optional cap for captured stdout/stderr bytes per stream.
    ///     If set, only the last N bytes are retained in memory and output is marked as truncated.
    /// - Returns: A `CommandResult` containing the output, exit status, and execution metadata.
    /// - Throws: `CommandExecutorError.timedOut` if the command exceeds the timeout duration, or errors from process execution.
    static func run(
        _ executableURL: URL,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        timeout: Duration? = nil,
        captureLimitBytes: Int? = nil
    ) async throws -> CommandResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        if let environment {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Keep a normalized capture limit for this execution.
        let normalizedCaptureLimit = captureLimitBytes.map { max(0, $0) }

        // Track execution start time for duration calculation
        let started = ContinuousClock.now

        // Thread-safe state tracking for cancellation, timeout, and completion
        // Using locks ensures safe access from multiple concurrent contexts
        let stateLock = OSAllocatedUnfairLock(initialState: (didCancel: false, didTimeout: false, didResume: false))

        // Asynchronous pipe reading prevents deadlocks when commands produce large outputs
        // Buffers are protected by locks to allow safe concurrent access
        let outputLock = OSAllocatedUnfairLock(initialState: (
            stdout: Data(),
            stderr: Data(),
            stdoutTotalBytes: 0,
            stderrTotalBytes: 0,
            stdoutTruncated: false,
            stderrTruncated: false
        ))

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                outputLock.withLock { state in
                    appendOutputChunk(
                        data,
                        buffer: &state.stdout,
                        totalBytes: &state.stdoutTotalBytes,
                        truncated: &state.stdoutTruncated,
                        captureLimitBytes: normalizedCaptureLimit
                    )
                }
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                outputLock.withLock { state in
                    appendOutputChunk(
                        data,
                        buffer: &state.stderr,
                        totalBytes: &state.stderrTotalBytes,
                        truncated: &state.stderrTruncated,
                        captureLimitBytes: normalizedCaptureLimit
                    )
                }
            }
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                // Finish handler called when the process terminates
                // Ensures continuation is resumed exactly once using lock-based coordination
                let finish: @Sendable (Int32) -> Void = { exitCode in
                    let shouldResume = stateLock.withLock { state -> Bool in
                        guard !state.didResume else { return false }
                        state.didResume = true
                        return true
                    }

                    // Skip if already resumed from timeout or cancellation
                    guard shouldResume else { return }

                    // Stop reading from pipes
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil

                    // Read any remaining data
                    let remainingStdout = stdoutPipe.fileHandleForReading.availableData
                    let remainingStderr = stderrPipe.fileHandleForReading.availableData

                    // Append remaining data and get final output
                    let capture = outputLock.withLock { state in
                        if !remainingStdout.isEmpty {
                            appendOutputChunk(
                                remainingStdout,
                                buffer: &state.stdout,
                                totalBytes: &state.stdoutTotalBytes,
                                truncated: &state.stdoutTruncated,
                                captureLimitBytes: normalizedCaptureLimit
                            )
                        }
                        if !remainingStderr.isEmpty {
                            appendOutputChunk(
                                remainingStderr,
                                buffer: &state.stderr,
                                totalBytes: &state.stderrTotalBytes,
                                truncated: &state.stderrTruncated,
                                captureLimitBytes: normalizedCaptureLimit
                            )
                        }
                        return (
                            stdout: state.stdout,
                            stderr: state.stderr,
                            stdoutTotalBytes: state.stdoutTotalBytes,
                            stderrTotalBytes: state.stderrTotalBytes,
                            stdoutTruncated: state.stdoutTruncated,
                            stderrTruncated: state.stderrTruncated
                        )
                    }

                    let stdout = renderedOutput(
                        data: capture.stdout,
                        wasTruncated: capture.stdoutTruncated,
                        totalBytes: capture.stdoutTotalBytes
                    )
                    let stderr = renderedOutput(
                        data: capture.stderr,
                        wasTruncated: capture.stderrTruncated,
                        totalBytes: capture.stderrTotalBytes
                    )

                    let (didCancel, didTimeout, _) = stateLock.withLock { state in
                        (state.didCancel, state.didTimeout, state.didResume)
                    }

                    let duration = started.duration(to: ContinuousClock.now)
                    let result = CommandResult(
                        executablePath: executableURL.path(),
                        arguments: arguments,
                        stdout: stdout,
                        stderr: stderr,
                        exitCode: exitCode,
                        wasCancelled: didCancel,
                        timedOut: didTimeout,
                        stdoutTruncated: capture.stdoutTruncated,
                        stderrTruncated: capture.stderrTruncated,
                        stdoutBytesTotal: capture.stdoutTotalBytes,
                        stderrBytesTotal: capture.stderrTotalBytes,
                        duration: duration
                    )

                    persistDiagnostics(
                        CommandExecutionDiagnostics(
                            timestamp: Date(),
                            executablePath: executableURL.path(),
                            arguments: arguments,
                            exitCode: exitCode,
                            wasCancelled: didCancel,
                            timedOut: didTimeout,
                            durationSeconds: durationSeconds(duration),
                            stdoutBytesTotal: capture.stdoutTotalBytes,
                            stderrBytesTotal: capture.stderrTotalBytes,
                            stdoutBytesCaptured: capture.stdout.count,
                            stderrBytesCaptured: capture.stderr.count,
                            stdoutTruncated: capture.stdoutTruncated,
                            stderrTruncated: capture.stderrTruncated,
                            captureLimitBytes: normalizedCaptureLimit,
                            launchError: nil
                        )
                    )

                    if didTimeout {
                        continuation.resume(throwing: CommandExecutorError.timedOut)
                    } else {
                        continuation.resume(returning: result)
                    }
                }

                process.terminationHandler = { terminatedProcess in
                    finish(terminatedProcess.terminationStatus)
                }

                do {
                    try process.run()

                    // Set up timeout handler if timeout is specified
                    if let timeout {
                        Task {
                            do {
                                try await Task.sleep(for: timeout)
                            } catch {
                                return
                            }

                            let shouldTimeout = stateLock.withLock { state -> Bool in
                                guard !state.didResume else { return false }
                                state.didTimeout = true
                                return true
                            }

                            if shouldTimeout, process.isRunning {
                                process.terminate()
                            }
                        }
                    }
                } catch {
                    let duration = started.duration(to: ContinuousClock.now)
                    persistDiagnostics(
                        CommandExecutionDiagnostics(
                            timestamp: Date(),
                            executablePath: executableURL.path(),
                            arguments: arguments,
                            exitCode: nil,
                            wasCancelled: false,
                            timedOut: false,
                            durationSeconds: durationSeconds(duration),
                            stdoutBytesTotal: 0,
                            stderrBytesTotal: 0,
                            stdoutBytesCaptured: 0,
                            stderrBytesCaptured: 0,
                            stdoutTruncated: false,
                            stderrTruncated: false,
                            captureLimitBytes: normalizedCaptureLimit,
                            launchError: error.localizedDescription
                        )
                    )
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            // Handle task cancellation by terminating the process
            let shouldCancel = stateLock.withLock { state -> Bool in
                guard !state.didResume else { return false }
                state.didCancel = true
                return true
            }

            if shouldCancel, process.isRunning {
                process.terminate()
            }
        }
    }

    /// Convenience method to run a command using a file path string.
    ///
    /// This is a wrapper around the main `run` method that accepts a string path
    /// instead of a URL for convenience.
    ///
    /// - Parameters:
    ///   - path: The file path of the executable to run.
    ///   - arguments: The command-line arguments to pass to the executable.
    ///   - environment: Optional environment variables to merge with the current process environment.
    ///   - timeout: Optional timeout duration.
    ///   - captureLimitBytes: Optional cap for captured stdout/stderr bytes per stream.
    /// - Returns: A `CommandResult` containing the output, exit status, and execution metadata.
    /// - Throws: `CommandExecutorError.timedOut` if the command exceeds the timeout duration, or errors from process execution.
    static func run(
        path: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        timeout: Duration? = nil,
        captureLimitBytes: Int? = nil
    ) async throws -> CommandResult {
        try await run(
            URL(filePath: path),
            arguments: arguments,
            environment: environment,
            timeout: timeout,
            captureLimitBytes: captureLimitBytes
        )
    }

    // MARK: - Private Helpers

    /// Appends stream data while honoring optional capture limits.
    ///
    /// When a limit is set, only the latest bytes are retained to avoid unbounded
    /// memory growth for very verbose commands (e.g., package upgrades).
    private static func appendOutputChunk(
        _ data: Data,
        buffer: inout Data,
        totalBytes: inout Int,
        truncated: inout Bool,
        captureLimitBytes: Int?
    ) {
        totalBytes += data.count

        guard let captureLimitBytes else {
            buffer.append(data)
            return
        }

        if captureLimitBytes == 0 {
            truncated = totalBytes > 0
            return
        }

        if data.count >= captureLimitBytes {
            buffer = Data(data.suffix(captureLimitBytes))
            truncated = true
            return
        }

        let overflow = (buffer.count + data.count) - captureLimitBytes
        if overflow > 0 {
            if overflow >= buffer.count {
                buffer.removeAll(keepingCapacity: true)
            } else {
                buffer.removeFirst(overflow)
            }
            truncated = true
        }

        buffer.append(data)
    }

    /// Renders captured output, adding a truncation header when needed.
    private static func renderedOutput(data: Data, wasTruncated: Bool, totalBytes: Int) -> String {
        let output = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)

        guard wasTruncated else {
            return output
        }

        return "[output truncated: showing last \(data.count) of \(totalBytes) bytes]\n\(output)"
    }

    /// Converts a `Duration` to seconds as a `Double`.
    private static func durationSeconds(_ duration: Duration) -> Double {
        let components = duration.components
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
        return seconds + attoseconds
    }

    /// Persists diagnostics for the last command execution.
    private static func persistDiagnostics(
        _ diagnostics: CommandExecutionDiagnostics,
        defaults: UserDefaults = .standard
    ) {
        do {
            let data = try JSONEncoder().encode(diagnostics)
            defaults.set(data, forKey: diagnosticsDefaultsKey)
        } catch {
            logger.error("Failed to persist command diagnostics: \(error.localizedDescription)")
        }
    }
}
