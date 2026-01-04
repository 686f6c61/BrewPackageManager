//
//  BrewLocator.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation
import OSLog

/// Locates the Homebrew executable on the system.
///
/// This utility checks common Homebrew installation paths and falls back to
/// searching the PATH if necessary. It validates found executables by running
/// `brew --version` to ensure they are functional.
nonisolated enum BrewLocator {

    // MARK: - Properties

    /// Logger for tracking location attempts and results.
    private static let logger = Logger(subsystem: "BrewPackageManager", category: "BrewLocator")

    /// Common installation paths for Homebrew.
    ///
    /// Checked in order before falling back to PATH search:
    /// - Apple Silicon default: /opt/homebrew/bin/brew
    /// - Intel default: /usr/local/bin/brew
    /// - Linux (for completeness): /home/linuxbrew/.linuxbrew/bin/brew
    private static let commonPaths: [String] = [
        "/opt/homebrew/bin/brew",
        "/usr/local/bin/brew",
        "/home/linuxbrew/.linuxbrew/bin/brew"
    ]

    // MARK: - Public Methods
    
    /// Attempts to locate the `brew` executable.
    /// - Returns: The URL to the brew executable if found.
    /// - Throws: `BrewLocatorError.brewNotFound` if Homebrew is not installed.
    static func locateBrew() async throws -> URL {
        // First, check common installation paths
        for path in commonPaths {
            let url = URL(filePath: path)

            // Try to validate even if isExecutableFile returns false
            if FileManager.default.fileExists(atPath: path) {
                logger.info("Found brew at common path: \(path)")
                if await validateBrew(at: url) {
                    return url
                }
            }
        }
        
        // Fall back to `which brew`
        logger.info("Checking PATH for brew using /usr/bin/which")
        if let brewPath = try await findBrewViaWhich() {
            let url = URL(filePath: brewPath)
            if await validateBrew(at: url) {
                return url
            }
        }
        
        logger.error("Homebrew not found on this system")
        throw BrewLocatorError.brewNotFound
    }

    // MARK: - Private Methods

    /// Validates that the brew executable works by running `brew --version`.
    ///
    /// - Parameter url: The URL to the potential brew executable.
    /// - Returns: `true` if the executable is valid and responds correctly, `false` otherwise.
    private static func validateBrew(at url: URL) async -> Bool {
        do {
            let result = try await CommandExecutor.run(url, arguments: ["--version"])
            let isValid = result.isSuccess && result.stdout.contains("Homebrew")
            if isValid {
                logger.info("Validated brew at \(url.path())")
            }
            return isValid
        } catch {
            logger.warning("Failed to validate brew at \(url.path()): \(error.localizedDescription)")
            return false
        }
    }

    /// Uses `/usr/bin/which` to find brew in the PATH.
    ///
    /// This method searches for the brew executable in standard PATH locations
    /// using the `which` command.
    ///
    /// - Returns: The path to the brew executable if found, or `nil` if not found.
    /// - Throws: Errors from command execution (though typically returns `nil` on failure).
    private static func findBrewViaWhich() async throws -> String? {
        let whichURL = URL(filePath: "/usr/bin/which")
        let environment: [String: String] = [
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        ]
        
        guard FileManager.default.isExecutableFile(atPath: whichURL.path()) else {
            return nil
        }
        
        let result = try await CommandExecutor.run(whichURL, arguments: ["brew"], environment: environment)
        
        guard result.isSuccess else {
            return nil
        }
        
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }
}
