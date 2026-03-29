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

    /// Max bytes captured per stream for verbose mutating operations.
    private let mutatingOutputCaptureLimitBytes = 1_048_576

    // MARK: - Initialization

    private func ensureBrewURL() async throws -> URL {
        if let brewURL {
            return brewURL
        }

        let url = try await BrewLocator.locateBrew()
        brewURL = url
        return url
    }

    private func ensureNotCancelled(_ result: CommandResult) throws {
        if result.wasCancelled {
            throw AppError.cancelled
        }
    }

    /// Resolves Homebrew's cache directory.
    ///
    /// `brew cleanup --prune=all` does not fully empty this directory for
    /// installed formulae/casks, so the app needs the real path to clear it.
    private func getCacheDirectoryURL() async throws -> URL {
        let brewURL = try await ensureBrewURL()
        let result = try await CommandExecutor.run(
            brewURL,
            arguments: ["--cache"],
            environment: environment,
            timeout: .seconds(10)
        )
        try ensureNotCancelled(result)

        guard result.exitCode == 0 else {
            logger.error("Failed to get cache directory: \(result.stderr)")
            throw AppError.shellCommandFailed(
                command: "brew --cache",
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        return try Self.parseCacheDirectoryURL(from: result.stdout)
    }

    /// Parses and validates the cache directory path returned by Homebrew.
    static func parseCacheDirectoryURL(from output: String) throws -> URL {
        let cachePath = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cachePath.isEmpty else {
            throw AppError.unknown("Homebrew returned an empty cache path.")
        }

        let cacheURL = URL(filePath: cachePath).standardizedFileURL
        guard cacheURL.path() != "/" else {
            throw AppError.unknown("Refusing to clear cache at the filesystem root.")
        }

        return cacheURL
    }

    /// Removes all contents inside the cache directory while keeping the root directory.
    static func clearDirectoryContents(at directoryURL: URL, fileManager: FileManager = .default) throws -> Int {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let children = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: []
        )

        for childURL in children {
            try fileManager.removeItem(at: childURL)
        }

        return children.count
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
        try ensureNotCancelled(result)

        guard result.exitCode == 0 else {
            logger.error("Failed to fetch cleanup info: \(result.stderr)")
            throw AppError.shellCommandFailed(
                command: "brew cleanup --dry-run -s",
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

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
        let cacheURL = try await getCacheDirectoryURL()
        let cachePath = cacheURL.path()

        // Get directory size using `du -sk`
        let duResult = try await CommandExecutor.run(
            path: "/usr/bin/du",
            arguments: ["-sk", cachePath],
            timeout: .seconds(30),
            captureLimitBytes: 16_384
        )
        try ensureNotCancelled(duResult)

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

        // Count files without materializing every path in memory.
        let countResult = try await CommandExecutor.run(
            path: "/bin/sh",
            arguments: [
                "-c",
                "/usr/bin/find \"$1\" -type f | /usr/bin/wc -l",
                "brew-cache-count",
                cachePath
            ],
            timeout: .seconds(30),
            captureLimitBytes: 16_384
        )
        try ensureNotCancelled(countResult)
        guard countResult.exitCode == 0 else {
            logger.warning("Failed to count cache files: \(countResult.stderr)")
            return (sizeInt * 1024, 0)
        }
        let fileCount = Int(
            countResult.stdout.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        ) ?? 0

        return (sizeInt * 1024, fileCount) // Convert KB to bytes
    }

    /// Perform cleanup operation.
    ///
    /// Executes `brew cleanup` to remove old versions and let Homebrew prune
    /// cache entries according to its current cleanup rules.
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
            timeout: .seconds(120),
            captureLimitBytes: mutatingOutputCaptureLimitBytes
        )
        try ensureNotCancelled(result)

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
    /// Homebrew keeps downloads for installed formulae/casks even with
    /// `brew cleanup --prune=all`, so this empties the cache directory directly.
    ///
    /// - Returns: Number of bytes freed.
    /// - Throws: `AppError` if the command fails.
    func clearCache() async throws -> Int64 {
        logger.info("Clearing download cache")

        let cacheDirectoryURL = try await getCacheDirectoryURL()

        // Get cache size before cleanup
        let beforeSize = try await getCacheSize().cacheSize

        let removedEntries = try Self.clearDirectoryContents(at: cacheDirectoryURL)
        logger.info("Removed \(removedEntries) entries from Homebrew cache directory")

        // Get cache size after cleanup
        let afterSize = try await getCacheSize().cacheSize

        let freedBytes = max(0, beforeSize - afterSize)
        logger.info("Freed \(ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file))")

        return freedBytes
    }
}
