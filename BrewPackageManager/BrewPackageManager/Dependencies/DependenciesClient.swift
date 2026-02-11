//
//  DependenciesClient.swift
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

/// Actor responsible for fetching package dependency information.
///
/// This actor provides thread-safe access to brew dependency commands:
/// - Getting dependencies for a specific package
/// - Getting reverse dependencies (what uses this package)
/// - Analyzing dependency trees
///
/// All operations are isolated to the actor's context to prevent race conditions.
@preconcurrency
actor DependenciesClient {

    // MARK: - Properties

    /// Logger for dependencies operations.
    private let logger = Logger(subsystem: "BrewPackageManager", category: "DependenciesClient")

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

    private func ensureNotCancelled(_ result: CommandResult) throws {
        if result.wasCancelled {
            throw AppError.cancelled
        }
    }

    // MARK: - Public Methods

    /// Fetch dependency information for a specific package.
    ///
    /// Executes `brew info --json=v2 <package>` to get detailed dependency information.
    ///
    /// - Parameter packageName: The name of the package.
    /// - Returns: `DependencyInfo` for the package.
    /// - Throws: `AppError` if the command fails or JSON parsing fails.
    func fetchDependencies(for packageName: String) async throws -> DependencyInfo {
        logger.info("Fetching dependencies for: \(packageName)")

        let brewURL = try await ensureBrewURL()
        let result = try await CommandExecutor.run(
            brewURL,
            arguments: ["info", "--json=v2", packageName],
            environment: environment,
            timeout: .seconds(30)
        )
        try ensureNotCancelled(result)

        guard result.exitCode == 0 else {
            logger.error("Failed to fetch dependencies for \(packageName): \(result.stderr)")
            throw AppError.shellCommandFailed(
                command: "brew info --json=v2 \(packageName)",
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        // Parse JSON response
        guard let data = result.stdout.data(using: String.Encoding.utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let formulae = json["formulae"] as? [[String: Any]],
              let formulaJson = formulae.first else {
            logger.error("Failed to parse dependencies JSON for \(packageName)")
            throw AppError.invalidJSONResponse(command: "brew info --json=v2 \(packageName)")
        }

        guard let depInfo = DependencyInfo.parse(from: formulaJson) else {
            logger.warning("Could not parse dependency info for \(packageName), returning empty")
            return .empty(packageName: packageName)
        }

        logger.info("Fetched \(depInfo.dependencyCount) dependencies for \(packageName)")

        return depInfo
    }

    /// Fetch dependencies for all installed packages.
    ///
    /// - Returns: Array of `DependencyInfo` for all installed packages.
    /// - Throws: `AppError` if the command fails.
    func fetchAllDependencies() async throws -> [DependencyInfo] {
        logger.info("Fetching dependencies for all installed packages")

        let brewURL = try await ensureBrewURL()
        let result = try await CommandExecutor.run(
            brewURL,
            arguments: ["info", "--json=v2", "--installed"],
            environment: environment,
            timeout: .seconds(120)
        )
        try ensureNotCancelled(result)

        guard result.exitCode == 0 else {
            logger.error("Failed to fetch installed package info: \(result.stderr)")
            throw AppError.shellCommandFailed(
                command: "brew info --json=v2 --installed",
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        let response: BrewInfoResponse
        do {
            response = try BrewInfoResponse.decode(from: result.stdout)
        } catch {
            logger.error("Failed to decode installed package info: \(error.localizedDescription)")
            throw AppError.invalidJSONResponse(command: "brew info --json=v2 --installed")
        }

        let dependencies = buildDependencyGraph(from: response.formulae)
        logger.info("Successfully fetched dependencies for \(dependencies.count) packages")
        return dependencies
    }

    /// Builds `DependencyInfo` entries and reverse dependency links from installed formulae.
    private func buildDependencyGraph(from formulae: [BrewInfoResponse.Formula]) -> [DependencyInfo] {
        var directDependencies: [String: [String]] = [:]
        var optionalDependencies: [String: [String]] = [:]
        var buildDependencies: [String: [String]] = [:]
        var declaredUsedBy: [String: [String]] = [:]
        var reverseDependencies: [String: Set<String>] = [:]

        for formula in formulae {
            let packageName = formula.name
            let deps = formula.dependencies ?? []

            directDependencies[packageName] = deps
            optionalDependencies[packageName] = formula.optionalDependencies ?? []
            buildDependencies[packageName] = formula.buildDependencies ?? []
            declaredUsedBy[packageName] = formula.usedBy ?? []

            for dependency in deps {
                reverseDependencies[dependency, default: []].insert(packageName)
            }
        }

        return directDependencies.keys.sorted().map { packageName in
            let reverse = reverseDependencies[packageName] ?? []
            let declared = Set(declaredUsedBy[packageName] ?? [])
            let usedBy = Array(reverse.union(declared)).sorted()

            return DependencyInfo(
                id: packageName,
                packageName: packageName,
                dependencies: directDependencies[packageName] ?? [],
                optionalDependencies: optionalDependencies[packageName] ?? [],
                buildDependencies: buildDependencies[packageName] ?? [],
                isUsedBy: usedBy
            )
        }
    }

    /// Get packages that depend on the specified package (reverse dependencies).
    ///
    /// Executes `brew uses --installed <package>` to find what uses this package.
    ///
    /// - Parameter packageName: The package name.
    /// - Returns: Array of package names that depend on this package.
    /// - Throws: `AppError` if the command fails.
    func fetchUsedBy(packageName: String) async throws -> [String] {
        logger.info("Fetching reverse dependencies for: \(packageName)")

        let brewURL = try await ensureBrewURL()
        let result = try await CommandExecutor.run(
            brewURL,
            arguments: ["uses", "--installed", packageName],
            environment: environment,
            timeout: .seconds(30)
        )
        try ensureNotCancelled(result)

        guard result.exitCode == 0 else {
            logger.error("Failed to fetch reverse dependencies for \(packageName): \(result.stderr)")
            throw AppError.shellCommandFailed(
                command: "brew uses --installed \(packageName)",
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        let usedBy = result.stdout
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        logger.info("Package \(packageName) is used by \(usedBy.count) packages")

        return usedBy
    }
}
