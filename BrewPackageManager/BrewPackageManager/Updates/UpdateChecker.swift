//
//  UpdateChecker.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//  Version: 1.6.0
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation
import OSLog

/// Handles application update checking logic.
///
/// This class coordinates between the GitHub API client and version comparison
/// logic to determine if updates are available. It respects user preferences
/// for skipped versions and update check timing.
@MainActor
final class UpdateChecker {

    // MARK: - Properties

    /// Logger for tracking update check operations.
    private let logger = Logger(subsystem: "BrewPackageManager", category: "UpdateChecker")

    /// GitHub API client for fetching releases.
    private let githubClient = GitHubClient()

    // MARK: - Constants

    /// Minimum interval between automatic update checks (24 hours in seconds)
    static let minimumCheckInterval: TimeInterval = 24 * 60 * 60

    // MARK: - Methods

    /// Checks for application updates.
    ///
    /// Fetches the latest release from GitHub and compares it with the current
    /// application version. Respects the user's skipped version preference.
    ///
    /// - Parameters:
    ///   - currentVersion: The current application version (from Bundle)
    ///   - skippedVersion: Optional version the user chose to skip
    /// - Returns: Update check result indicating if update is available
    func checkForUpdates(
        currentVersion: String,
        skippedVersion: String? = nil
    ) async -> UpdateCheckResult {
        logger.info("Checking for updates (current: \(currentVersion))...")

        do {
            let release = try await githubClient.fetchLatestRelease()
            let latestVersion = release.version

            logger.info("Latest version: \(latestVersion)")

            // Check if user already skipped this version
            if let skippedVersion, skippedVersion == latestVersion {
                logger.info("User previously skipped version \(latestVersion)")
                return .upToDate
            }

            // Compare versions
            let isNewer = try VersionComparator.isNewerVersion(
                current: currentVersion,
                latest: latestVersion
            )

            if isNewer {
                logger.info("Update available: \(latestVersion)")
                return .updateAvailable(release)
            } else {
                logger.info("Application is up to date")
                return .upToDate
            }

        } catch let error as AppError {
            logger.error("Update check failed: \(error.localizedDescription ?? "Unknown error")")
            return .error(error)
        } catch {
            logger.error("Unexpected error: \(error.localizedDescription)")
            return .error(.updateCheckFailed(reason: error.localizedDescription))
        }
    }

    /// Determines if an automatic update check should be performed.
    ///
    /// Checks if sufficient time has passed since the last update check
    /// based on the configured interval.
    ///
    /// - Parameter lastCheck: Date of the last update check, or nil if never checked
    /// - Returns: `true` if a check should be performed, `false` otherwise
    static func shouldCheckForUpdates(lastCheck: Date?) -> Bool {
        guard let lastCheck else {
            return true  // Never checked before
        }

        let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
        return timeSinceLastCheck >= minimumCheckInterval
    }
}
