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
    /// - Returns: A `CommandResult` containing the output, exit status, and execution metadata.
    /// - Throws: `CommandExecutorError.timedOut` if the command exceeds the timeout duration, or errors from process execution.
    static func run(
        _ executableURL: URL,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        timeout: Duration? = nil
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

        // Track execution start time for duration calculation
        let started = ContinuousClock.now

        // Thread-safe state tracking for cancellation, timeout, and completion
        // Using locks ensures safe access from multiple concurrent contexts
        let stateLock = OSAllocatedUnfairLock(initialState: (didCancel: false, didTimeout: false, didResume: false))

        // Asynchronous pipe reading prevents deadlocks when commands produce large outputs
        // Buffers are protected by locks to allow safe concurrent access
        let outputLock = OSAllocatedUnfairLock(initialState: (stdout: Data(), stderr: Data()))

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                outputLock.withLock { state in
                    state.stdout.append(data)
                }
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                outputLock.withLock { state in
                    state.stderr.append(data)
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
                    let (stdoutData, stderrData) = outputLock.withLock { state in
                        if !remainingStdout.isEmpty {
                            state.stdout.append(remainingStdout)
                        }
                        if !remainingStderr.isEmpty {
                            state.stderr.append(remainingStderr)
                        }
                        return (state.stdout, state.stderr)
                    }

                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                    let (didCancel, didTimeout, _) = stateLock.withLock { state in
                        (state.didCancel, state.didTimeout, state.didResume)
                    }

                    let result = CommandResult(
                        executablePath: executableURL.path(),
                        arguments: arguments,
                        stdout: stdout,
                        stderr: stderr,
                        exitCode: exitCode,
                        wasCancelled: didCancel,
                        duration: started.duration(to: ContinuousClock.now)
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
    /// - Returns: A `CommandResult` containing the output, exit status, and execution metadata.
    /// - Throws: `CommandExecutorError.timedOut` if the command exceeds the timeout duration, or errors from process execution.
    static func run(
        path: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        timeout: Duration? = nil
    ) async throws -> CommandResult {
        try await run(URL(filePath: path), arguments: arguments, environment: environment, timeout: timeout)
    }
}
