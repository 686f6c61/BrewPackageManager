//
//  CleanupClient.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//  Version: 1.7.0
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation
import OSLog

/// Actor responsible for executing Homebrew cleanup operations.
///
/// This actor provides thread-safe access to brew cleanup commands:
/// - Checking cache size and old versions
/// - Performing cleanup operations
/// - Clearing download cache
///
/// All operations are isolated to the actor's context to prevent race conditions.
@preconcurrency
actor CleanupClient {

    // MARK: - Properties

    /// Logger for cleanup operations.
    private let logger = Logger(subsystem: "BrewPackageManager", category: "CleanupClient")

    /// The resolved path to the brew executable.
    private var brewURL: URL?

    /// Environment variables to pass to brew commands.
    private let environment: [String: String] = [
        "HOMEBREW_NO_AUTO_UPDATE": "1",
        "HOMEBREW_NO_INSTALL_CLEANUP": "1"
    ]

    // MARK: - Initialization

    private func ensureBrewURL() async throws -> URL {
        if let brewURL {
            return brewURL
        }

        let url = try await BrewLocator.locateBrew()
        brewURL = url
        return url
    }

    // MARK: - Public Methods

    /// Get cleanup information (cache size, old versions).
    ///
    /// Executes `brew cleanup --dry-run` to see what would be cleaned without actually cleaning.
    ///
    /// - Returns: `CleanupInfo` with cache statistics.
    /// - Throws: `AppError` if the command fails.
    func getCleanupInfo() async throws -> CleanupInfo {
        logger.info("Fetching cleanup information")

        // Check cache directory size
        let cacheInfo = try await getCacheSize()

        // Check for old versions
        let brewURL = try await ensureBrewURL()
        let result = try await CommandExecutor.run(
            brewURL,
            arguments: ["cleanup", "--dry-run", "-s"],
            environment: environment,
            timeout: .seconds(60)
        )

        let info = CleanupInfo.parseFromOutput(stdout: result.stdout)

        logger.info("Cleanup info: \(ByteCountFormatter.string(fromByteCount: cacheInfo.cacheSize, countStyle: .file)) cache, \(info.oldVersions) old versions")

        return CleanupInfo(
            cacheSize: cacheInfo.cacheSize,
            cachedFiles: cacheInfo.cachedFiles,
            oldVersions: info.oldVersions
        )
    }

    /// Get the size of Homebrew's cache directory.
    ///
    /// - Returns: Tuple with cache size and file count.
    /// - Throws: `AppError` if the command fails.
    private func getCacheSize() async throws -> (cacheSize: Int64, cachedFiles: Int) {
        let brewURL = try await ensureBrewURL()
        let result = try await CommandExecutor.run(
            brewURL,
            arguments: ["--cache"],
            environment: environment,
            timeout: .seconds(10)
        )

        guard result.exitCode == 0 else {
            logger.error("Failed to get cache directory: \(result.stderr)")
            throw AppError.shellCommandFailed(
                command: "brew --cache",
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        let cachePath = result.stdout.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        // Get directory size using `du -sk`
        let duResult = try await CommandExecutor.run(
            path: "/usr/bin/du",
            arguments: ["-sk", cachePath],
            timeout: .seconds(30)
        )

        guard duResult.exitCode == 0 else {
            logger.warning("Failed to calculate cache size, returning 0")
            return (0, 0)
        }

        // Parse du output: "12345\t/path/to/cache"
        let components = duResult.stdout.split(separator: "\t")
        guard let sizeKB = components.first,
              let sizeInt = Int64(sizeKB.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) else {
            return (0, 0)
        }

        // Count files in cache
        let lsResult = try await CommandExecutor.run(
            path: "/usr/bin/find",
            arguments: [cachePath, "-type", "f"],
            timeout: .seconds(30)
        )
        let fileCount = lsResult.stdout.split(separator: "\n").count

        return (sizeInt * 1024, fileCount) // Convert KB to bytes
    }

    /// Perform cleanup operation.
    ///
    /// Executes `brew cleanup` to remove old versions and cached downloads.
    ///
    /// - Parameter pruneAll: If true, removes all cached downloads (--prune=all).
    /// - Returns: Cleanup result message.
    /// - Throws: `AppError` if the command fails.
    func performCleanup(pruneAll: Bool = false) async throws -> String {
        logger.info("Performing cleanup (pruneAll: \(pruneAll))")

        var args = ["cleanup", "-s"]
        if pruneAll {
            args.append("--prune=all")
        }

        let brewURL = try await ensureBrewURL()
        let result = try await CommandExecutor.run(
            brewURL,
            arguments: args,
            environment: environment,
            timeout: .seconds(120)
        )

        guard result.exitCode == 0 else {
            logger.error("Failed to cleanup: \(result.stderr)")
            throw AppError.shellCommandFailed(
                command: args.joined(separator: " "),
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        let message = result.stdout.isEmpty ? "Cleanup completed successfully" : result.stdout
        logger.info("Cleanup completed: \(message)")

        return message
    }

    /// Clear download cache.
    ///
    /// Executes `brew cleanup --prune=all` to remove all cached downloads.
    ///
    /// - Returns: Number of bytes freed.
    /// - Throws: `AppError` if the command fails.
    func clearCache() async throws -> Int64 {
        logger.info("Clearing download cache")

        // Get cache size before cleanup
        let beforeSize = try await getCacheSize().cacheSize

        // Perform cleanup with prune=all
        _ = try await performCleanup(pruneAll: true)

        // Get cache size after cleanup
        let afterSize = try await getCacheSize().cacheSize

        let freedBytes = beforeSize - afterSize
        logger.info("Freed \(ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file))")

        return freedBytes
    }
}
