//
//  CleanupStore.swift
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
import Observation

/// Store for managing cleanup and cache operations.
///
/// This observable store coordinates fetching cleanup information
/// and performing cleanup operations.
@MainActor
@Observable
final class CleanupStore {

    // MARK: - Properties

    /// Current cleanup information.
    var cleanupInfo: CleanupInfo = .empty

    /// Whether the store is currently loading information.
    var isLoading = false

    /// Whether a cleanup operation is in progress.
    var isCleaning = false

    /// The last error that occurred.
    var lastError: AppError?

    /// Result message from last cleanup.
    var lastCleanupResult: String?

    /// Logger for cleanup store operations.
    private let logger = Logger(subsystem: "BrewPackageManager", category: "CleanupStore")

    /// Cleanup client for executing commands.
    private let client = CleanupClient()

    // MARK: - Public Methods

    /// Fetch cleanup information from Homebrew.
    func fetchCleanupInfo() async {
        guard !isLoading else { return }

        isLoading = true
        lastError = nil

        logger.info("Fetching cleanup info")

        do {
            let info = try await client.getCleanupInfo()
            cleanupInfo = info
            logger.info("Successfully fetched cleanup info: \(info.cacheSizeFormatted)")
        } catch let error as AppError {
            logger.error("Failed to fetch cleanup info: \(error.localizedDescription)")
            lastError = error
        } catch {
            logger.error("Unexpected error fetching cleanup info: \(error.localizedDescription)")
            lastError = AppError.unknown(error.localizedDescription)
        }

        isLoading = false
    }

    /// Perform cleanup operation.
    ///
    /// - Parameter pruneAll: If true, removes all cached downloads.
    func performCleanup(pruneAll: Bool = false) async {
        guard !isCleaning else { return }

        isCleaning = true
        lastError = nil
        lastCleanupResult = nil

        logger.info("Performing cleanup (pruneAll: \(pruneAll))")

        do {
            let result = try await client.performCleanup(pruneAll: pruneAll)
            lastCleanupResult = result
            logger.info("Cleanup completed successfully")

            // Refresh cleanup info after operation
            await fetchCleanupInfo()
        } catch let error as AppError {
            logger.error("Failed to perform cleanup: \(error.localizedDescription)")
            lastError = error
        } catch {
            logger.error("Unexpected error during cleanup: \(error.localizedDescription)")
            lastError = AppError.unknown(error.localizedDescription)
        }

        isCleaning = false
    }

    /// Clear download cache completely.
    func clearCache() async {
        guard !isCleaning else { return }

        isCleaning = true
        lastError = nil
        lastCleanupResult = nil

        logger.info("Clearing cache")

        do {
            let freedBytes = try await client.clearCache()
            lastCleanupResult = "Freed \(ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file))"
            logger.info("Cache cleared: \(freedBytes) bytes freed")

            // Refresh cleanup info after operation
            await fetchCleanupInfo()
        } catch let error as AppError {
            logger.error("Failed to clear cache: \(error.localizedDescription)")
            lastError = error
        } catch {
            logger.error("Unexpected error clearing cache: \(error.localizedDescription)")
            lastError = AppError.unknown(error.localizedDescription)
        }

        isCleaning = false
    }
}
