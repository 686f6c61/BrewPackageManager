//
//  ServicesClient.swift
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

/// Actor responsible for executing Homebrew services commands.
///
/// This actor provides thread-safe access to brew services operations:
/// - Listing all services
/// - Starting/stopping services
/// - Restarting services
///
/// All operations are isolated to the actor's context to prevent race conditions.
@preconcurrency
actor ServicesClient {

    // MARK: - Properties

    /// Logger for services operations.
    private let logger = Logger(subsystem: "BrewPackageManager", category: "ServicesClient")

    /// The resolved path to the brew executable.
    private var brewURL: URL?

    /// Environment variables to pass to brew commands.
    private let environment: [String: String] = [
        "HOMEBREW_NO_AUTO_UPDATE": "1",
        "HOMEBREW_NO_INSTALL_CLEANUP": "1"
    ]

    /// Max bytes captured per stream for service mutations.
    private let mutatingOutputCaptureLimitBytes = 262_144

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

    // MARK: - Public Methods

    /// Fetch all Homebrew services with their current status.
    ///
    /// Executes `brew services list --json` to retrieve service information.
    ///
    /// - Returns: Array of `BrewService` objects.
    /// - Throws: `AppError` if the command fails or JSON parsing fails.
    func fetchServices() async throws -> [BrewService] {
        logger.info("Fetching Homebrew services list")

        let brewURL = try await ensureBrewURL()
        let result = try await CommandExecutor.run(
            brewURL,
            arguments: ["services", "list", "--json"],
            environment: environment,
            timeout: .seconds(30)
        )
        try ensureNotCancelled(result)

        guard result.exitCode == 0 else {
            logger.error("Failed to fetch services: \(result.stderr)")
            throw AppError.shellCommandFailed(
                command: "brew services list --json",
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        // Parse JSON response
        guard let data = result.stdout.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            logger.error("Failed to parse services JSON")
            throw AppError.invalidJSONResponse(command: "brew services list --json")
        }

        let services = jsonArray.compactMap { BrewService.parse(from: $0) }
        logger.info("Fetched \(services.count) services")

        return services
    }

    /// Start a Homebrew service.
    ///
    /// - Parameter serviceName: The name of the service to start.
    /// - Throws: `AppError` if the command fails.
    func startService(_ serviceName: String) async throws {
        logger.info("Starting service: \(serviceName)")

        let brewURL = try await ensureBrewURL()
        let result = try await CommandExecutor.run(
            brewURL,
            arguments: ["services", "start", serviceName],
            environment: environment,
            timeout: .seconds(30),
            captureLimitBytes: mutatingOutputCaptureLimitBytes
        )
        try ensureNotCancelled(result)

        guard result.exitCode == 0 else {
            logger.error("Failed to start service \(serviceName): \(result.stderr)")
            throw AppError.shellCommandFailed(
                command: "brew services start \(serviceName)",
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        logger.info("Service \(serviceName) started successfully")
    }

    /// Stop a Homebrew service.
    ///
    /// - Parameter serviceName: The name of the service to stop.
    /// - Throws: `AppError` if the command fails.
    func stopService(_ serviceName: String) async throws {
        logger.info("Stopping service: \(serviceName)")

        let brewURL = try await ensureBrewURL()
        let result = try await CommandExecutor.run(
            brewURL,
            arguments: ["services", "stop", serviceName],
            environment: environment,
            timeout: .seconds(30),
            captureLimitBytes: mutatingOutputCaptureLimitBytes
        )
        try ensureNotCancelled(result)

        guard result.exitCode == 0 else {
            logger.error("Failed to stop service \(serviceName): \(result.stderr)")
            throw AppError.shellCommandFailed(
                command: "brew services stop \(serviceName)",
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        logger.info("Service \(serviceName) stopped successfully")
    }

    /// Restart a Homebrew service.
    ///
    /// - Parameter serviceName: The name of the service to restart.
    /// - Throws: `AppError` if the command fails.
    func restartService(_ serviceName: String) async throws {
        logger.info("Restarting service: \(serviceName)")

        let brewURL = try await ensureBrewURL()
        let result = try await CommandExecutor.run(
            brewURL,
            arguments: ["services", "restart", serviceName],
            environment: environment,
            timeout: .seconds(30),
            captureLimitBytes: mutatingOutputCaptureLimitBytes
        )
        try ensureNotCancelled(result)

        guard result.exitCode == 0 else {
            logger.error("Failed to restart service \(serviceName): \(result.stderr)")
            throw AppError.shellCommandFailed(
                command: "brew services restart \(serviceName)",
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        logger.info("Service \(serviceName) restarted successfully")
    }
}
