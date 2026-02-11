//
//  GitHubClient.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//  Version: 1.6.0
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

@preconcurrency import Foundation
import OSLog

/// Actor for interacting with the GitHub API.
///
/// Provides thread-safe access to GitHub's releases API for checking
/// application updates. All operations are executed serially to prevent
/// race conditions.
@preconcurrency
actor GitHubClient {

    // MARK: - Properties

    /// Logger for tracking network operations.
    private let logger = Logger(subsystem: "BrewPackageManager", category: "GitHubClient")

    /// URL session for network requests.
    private let session: URLSession

    /// User-Agent value used for GitHub API requests.
    private let userAgent: String

    /// Timeout for network requests (10 seconds).
    private let timeout: TimeInterval = 10.0

    // MARK: - Constants

    /// GitHub API endpoint for latest release
    private static let releasesURL = "https://api.github.com/repos/686f6c61/BrewPackageManager/releases/latest"

    // MARK: - Initialization

    init(session: URLSession = .shared) {
        self.session = session
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.8.0"
        self.userAgent = "BrewPackageManager/\(version)"
    }

    // MARK: - Methods

    /// Fetches the latest release information from GitHub.
    ///
    /// Makes a GET request to the GitHub Releases API with a 10-second timeout.
    /// Includes User-Agent header as required by GitHub API.
    ///
    /// - Returns: Release information for the latest version.
    /// - Throws: `AppError.networkRequestFailed` for network errors or
    ///           `AppError.updateCheckFailed` for API/parsing errors.
    func fetchLatestRelease() async throws -> ReleaseInfo {
        guard let url = URL(string: Self.releasesURL) else {
            throw AppError.updateCheckFailed(reason: "Invalid GitHub API URL")
        }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        logger.info("Fetching latest release from GitHub...")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("Network request failed: \(error.localizedDescription)")
            throw AppError.networkRequestFailed(underlyingError: error.localizedDescription)
        }

        // Check HTTP status code
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                logger.error("GitHub API returned status code: \(httpResponse.statusCode)")
                throw AppError.updateCheckFailed(reason: "HTTP \(httpResponse.statusCode)")
            }
        }

        // Decode JSON response
        do {
            let decoder = JSONDecoder()
            let release = try decoder.decode(ReleaseInfo.self, from: data)

            logger.info("Successfully fetched release: \(release.tagName)")
            return release
        } catch {
            logger.error("Failed to decode release info: \(error.localizedDescription)")
            throw AppError.updateCheckFailed(reason: "Invalid response format")
        }
    }
}
