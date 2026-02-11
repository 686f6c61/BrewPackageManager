//
//  BrewPackagesClient.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//  Version: 1.5.0
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

@preconcurrency import Foundation
import OSLog

/// An actor that executes Homebrew package commands serially.
///
/// This actor provides a thread-safe interface for executing Homebrew commands
/// related to package management. All operations are executed serially to prevent
/// race conditions and ensure data consistency.
///
/// The client handles:
/// - Listing installed packages (formulae and casks)
/// - Checking for outdated packages
/// - Retrieving detailed package information
/// - Upgrading individual or all packages
/// - Uninstalling packages
///
/// All commands are executed with environment variables to prevent automatic
/// updates and cleanup during operations.
@preconcurrency
actor BrewPackagesClient: BrewPackagesClientProtocol {

    // MARK: - Properties

    /// Logger for tracking client operations and debugging.
    private let logger = Logger(subsystem: "BrewPackageManager", category: "BrewPackagesClient")

    /// The resolved path to the brew executable.
    /// Lazily determined on first use via BrewLocator.
    private var brewURL: URL?

    /// Environment variables to pass to brew commands.
    /// Prevents automatic updates and cleanup during operations.
    private let environment: [String: String] = [
        "HOMEBREW_NO_AUTO_UPDATE": "1",
        "HOMEBREW_NO_INSTALL_CLEANUP": "1"
    ]

    /// Max bytes captured per stream for verbose mutating operations.
    ///
    /// Limits in-memory growth when commands like `brew upgrade` emit very large logs.
    private let mutatingOutputCaptureLimitBytes = 1_048_576

    // MARK: - Error Mapping

    /// Maps execution errors to appropriate AppError types.
    ///
    /// This method converts low-level command executor errors into domain-specific
    /// errors that are more meaningful to the application layer.
    ///
    /// - Parameter error: The error to map.
    /// - Returns: An AppError representing the failure, or the original error if not mapped.
    private func mapExecutionError(_ error: Error) -> Error {
        if error is CancellationError {
            return AppError.cancelled
        }

        if let executorError = error as? CommandExecutorError, executorError == .timedOut {
            return AppError.commandTimedOut
        }

        return error
    }

    /// Ensures the command result was not cancelled.
    ///
    /// - Parameter result: The command result to check.
    /// - Throws: `AppError.cancelled` if the result indicates cancellation.
    private func ensureNotCancelled(_ result: CommandResult) throws {
        if result.wasCancelled {
            throw AppError.cancelled
        }
    }

    // MARK: - Initialization

    /// Ensures the brew executable is located before running commands.
    ///
    /// This method lazily locates and caches the brew executable path on first use.
    ///
    /// - Returns: The URL to the brew executable.
    /// - Throws: `BrewLocatorError.brewNotFound` if Homebrew cannot be found.
    private func ensureBrewURL() async throws -> URL {
        if let brewURL {
            return brewURL
        }

        let url = try await BrewLocator.locateBrew()
        brewURL = url
        return url
    }

    // MARK: - List Installed

    /// Lists all packages installed via Homebrew.
    ///
    /// This method executes `brew info --json=v2 --installed` to retrieve
    /// information about all installed formulae and casks.
    ///
    /// - Parameter debugMode: Whether to run the command in debug mode with verbose output.
    /// - Returns: An array of installed packages (both formulae and casks).
    /// - Throws: `AppError` for various failure conditions including brew not found,
    ///           command timeouts, execution failures, or JSON decoding errors.
    func listInstalledPackages(debugMode: Bool) async throws -> [BrewPackage] {
        let brewURL = try await ensureBrewURL()
        let arguments = BrewPackagesArgumentsBuilder.listInstalledArguments(type: nil, debugMode: debugMode)

        logger.info("Running: brew \(arguments.joined(separator: " "))")

        let result: CommandResult
        do {
            result = try await CommandExecutor.run(
                brewURL,
                arguments: arguments,
                environment: environment,
                timeout: .seconds(300)  // Increased from 60 to 300 seconds (5 minutes)
            )
        } catch {
            throw mapExecutionError(error)
        }

        try ensureNotCancelled(result)

        guard result.isSuccess else {
            logger.error("brew info failed: \(result.stderr)")
            throw AppError.brewFailed(exitCode: result.exitCode, stderr: result.stderr)
        }

        return try decodeInstalledPackages(from: result.stdout)
    }

    // MARK: - List Outdated

    /// Lists the names of all outdated packages.
    ///
    /// This method executes `brew outdated --json=v2` to find packages with
    /// available updates.
    ///
    /// - Parameter debugMode: Whether to run the command in debug mode with verbose output.
    /// - Returns: An array of package names that have updates available.
    /// - Throws: `AppError` for various failure conditions.
    func listOutdatedPackages(debugMode: Bool) async throws -> [String] {
        let brewURL = try await ensureBrewURL()
        let arguments = BrewPackagesArgumentsBuilder.outdatedArguments(debugMode: debugMode)

        logger.info("Running: brew \(arguments.joined(separator: " "))")

        let result: CommandResult
        do {
            result = try await CommandExecutor.run(
                brewURL,
                arguments: arguments,
                environment: environment,
                timeout: .seconds(60)
            )
        } catch {
            throw mapExecutionError(error)
        }

        try ensureNotCancelled(result)

        guard result.isSuccess else {
            logger.error("brew outdated failed: \(result.stderr)")
            throw AppError.brewFailed(exitCode: result.exitCode, stderr: result.stderr)
        }

        return try decodeOutdatedPackages(from: result.stdout)
    }

    /// Lists all pinned formula names.
    ///
    /// This method executes `brew list --pinned` and parses line-delimited output.
    ///
    /// - Parameter debugMode: Whether to run the command in debug mode with verbose output.
    /// - Returns: Set of pinned formula names.
    /// - Throws: `AppError` for various failure conditions.
    func listPinnedPackages(debugMode: Bool) async throws -> Set<String> {
        let brewURL = try await ensureBrewURL()
        let arguments = BrewPackagesArgumentsBuilder.listPinnedArguments(debugMode: debugMode)

        logger.info("Running: brew \(arguments.joined(separator: " "))")

        let result: CommandResult
        do {
            result = try await CommandExecutor.run(
                brewURL,
                arguments: arguments,
                environment: environment,
                timeout: .seconds(30)
            )
        } catch {
            throw mapExecutionError(error)
        }

        try ensureNotCancelled(result)

        guard result.isSuccess else {
            logger.error("brew list --pinned failed: \(result.stderr)")
            throw AppError.brewFailed(exitCode: result.exitCode, stderr: result.stderr)
        }

        let names = result.stdout
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Set(names)
    }

    // MARK: - Package Info

    /// Retrieves detailed information about a specific package.
    ///
    /// This method executes `brew info --json=v2 <package>` to get comprehensive
    /// information including versions, URLs, installation status, and metadata.
    ///
    /// - Parameters:
    ///   - packageName: The name of the package to query.
    ///   - type: Optional package type to disambiguate formula vs cask names.
    ///   - debugMode: Whether to run the command in debug mode with verbose output.
    /// - Returns: Detailed package information.
    /// - Throws: `AppError` for various failure conditions.
    func getPackageInfo(_ packageName: String, type: PackageType?, debugMode: Bool) async throws -> BrewPackageInfo {
        let brewURL = try await ensureBrewURL()
        let arguments = BrewPackagesArgumentsBuilder.infoArguments(
            packageName: packageName,
            type: type,
            debugMode: debugMode
        )

        logger.info("Running: brew \(arguments.joined(separator: " "))")

        let result: CommandResult
        do {
            result = try await CommandExecutor.run(
                brewURL,
                arguments: arguments,
                environment: environment,
                timeout: .seconds(30)
            )
        } catch {
            throw mapExecutionError(error)
        }

        try ensureNotCancelled(result)

        guard result.isSuccess else {
            logger.error("brew info failed: \(result.stderr)")
            throw AppError.brewFailed(exitCode: result.exitCode, stderr: result.stderr)
        }

        return try decodePackageInfo(from: result.stdout)
    }

    // MARK: - Upgrade

    /// Upgrades a specific package to its latest version.
    ///
    /// This method executes `brew upgrade <package>` with a 10-minute timeout.
    ///
    /// - Parameters:
    ///   - packageName: The name of the package to upgrade.
    ///   - type: The package type (formula or cask).
    ///   - debugMode: Whether to run the command in debug mode with verbose output.
    /// - Throws: `AppError` for various failure conditions.
    func upgradePackage(_ packageName: String, type: PackageType, debugMode: Bool) async throws {
        let brewURL = try await ensureBrewURL()
        let arguments = BrewPackagesArgumentsBuilder.upgradePackageArguments(
            packageName: packageName,
            type: type,
            debugMode: debugMode
        )

        logger.info("Running: brew \(arguments.joined(separator: " "))")

        let result: CommandResult
        do {
            result = try await CommandExecutor.run(
                brewURL,
                arguments: arguments,
                environment: environment,
                timeout: .seconds(600), // 10 minutes for upgrades
                captureLimitBytes: mutatingOutputCaptureLimitBytes
            )
        } catch {
            throw mapExecutionError(error)
        }

        try ensureNotCancelled(result)

        guard result.isSuccess else {
            logger.error("brew upgrade failed: \(result.stderr)")
            throw AppError.brewFailed(exitCode: result.exitCode, stderr: result.stderr)
        }

        logger.info("Successfully upgraded \(packageName)")
    }

    /// Upgrades all outdated packages to their latest versions.
    ///
    /// This method executes `brew upgrade` without arguments, upgrading all packages
    /// with a 30-minute timeout to accommodate large upgrade operations.
    ///
    /// - Parameter debugMode: Whether to run the command in debug mode with verbose output.
    /// - Throws: `AppError` for various failure conditions.
    func upgradeAllPackages(debugMode: Bool) async throws {
        let brewURL = try await ensureBrewURL()
        let arguments = BrewPackagesArgumentsBuilder.upgradeAllArguments(debugMode: debugMode)

        logger.info("Running: brew \(arguments.joined(separator: " "))")

        let result: CommandResult
        do {
            result = try await CommandExecutor.run(
                brewURL,
                arguments: arguments,
                environment: environment,
                timeout: .seconds(1800), // 30 minutes for upgrade all
                captureLimitBytes: mutatingOutputCaptureLimitBytes
            )
        } catch {
            throw mapExecutionError(error)
        }

        try ensureNotCancelled(result)

        guard result.isSuccess else {
            logger.error("brew upgrade failed: \(result.stderr)")
            throw AppError.brewFailed(exitCode: result.exitCode, stderr: result.stderr)
        }

        logger.info("Successfully upgraded all packages")
    }

    // MARK: - Uninstall

    /// Uninstalls a specific package.
    ///
    /// This method executes `brew uninstall <package>` with a 2-minute timeout.
    ///
    /// - Parameters:
    ///   - packageName: The name of the package to uninstall.
    ///   - type: The package type (formula or cask).
    ///   - debugMode: Whether to run the command in debug mode with verbose output.
    /// - Throws: `AppError` for various failure conditions.
    func uninstallPackage(_ packageName: String, type: PackageType, debugMode: Bool) async throws {
        let brewURL = try await ensureBrewURL()
        let arguments = BrewPackagesArgumentsBuilder.uninstallPackageArguments(
            packageName: packageName,
            type: type,
            debugMode: debugMode
        )

        logger.info("Running: brew \(arguments.joined(separator: " "))")

        let result: CommandResult
        do {
            result = try await CommandExecutor.run(
                brewURL,
                arguments: arguments,
                environment: environment,
                timeout: .seconds(120), // 2 minutes for uninstall
                captureLimitBytes: mutatingOutputCaptureLimitBytes
            )
        } catch {
            throw mapExecutionError(error)
        }

        try ensureNotCancelled(result)

        guard result.isSuccess else {
            logger.error("brew uninstall failed: \(result.stderr)")
            throw AppError.brewFailed(exitCode: result.exitCode, stderr: result.stderr)
        }

        logger.info("Successfully uninstalled \(packageName)")
    }

    // MARK: - Search

    /// Searches for packages matching the given query.
    ///
    /// This method executes `brew search [--formula|--cask] <query>` with a 30-second timeout.
    /// The output is a line-delimited list of package names.
    ///
    /// - Parameters:
    ///   - query: The search term to query.
    ///   - type: Optional package type filter (formula or cask).
    ///   - debugMode: Whether to run the command in debug mode with verbose output.
    /// - Returns: Array of package names matching the search.
    /// - Throws: `AppError` for various failure conditions.
    func searchPackages(_ query: String, type: PackageType?, debugMode: Bool) async throws -> [String] {
        let brewURL = try await ensureBrewURL()
        let arguments = BrewPackagesArgumentsBuilder.searchArguments(query: query, type: type, debugMode: debugMode)

        logger.info("Running: brew \(arguments.joined(separator: " "))")

        let result: CommandResult
        do {
            result = try await CommandExecutor.run(
                brewURL,
                arguments: arguments,
                environment: environment,
                timeout: .seconds(30) // 30 seconds for search
            )
        } catch {
            throw mapExecutionError(error)
        }

        try ensureNotCancelled(result)

        guard result.isSuccess else {
            logger.error("brew search failed: \(result.stderr)")
            throw AppError.brewFailed(exitCode: result.exitCode, stderr: result.stderr)
        }

        // Parse line-delimited output
        let packageNames = result.stdout
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        logger.info("Found \(packageNames.count) packages matching '\(query)'")
        return packageNames
    }

    // MARK: - Install

    /// Installs a package.
    ///
    /// This method executes `brew install [--cask] <package>` with a 10-minute timeout.
    ///
    /// - Parameters:
    ///   - packageName: The name of the package to install.
    ///   - type: The package type (formula or cask).
    ///   - debugMode: Whether to run the command in debug mode with verbose output.
    /// - Throws: `AppError` for various failure conditions.
    func installPackage(_ packageName: String, type: PackageType, debugMode: Bool) async throws {
        let brewURL = try await ensureBrewURL()
        let resolvedType = try await resolveInstallType(
            packageName: packageName,
            preferredType: type,
            debugMode: debugMode
        )
        let arguments = BrewPackagesArgumentsBuilder.installPackageArguments(
            packageName: packageName,
            type: resolvedType,
            debugMode: debugMode
        )

        logger.info("Running: brew \(arguments.joined(separator: " "))")

        let result: CommandResult
        do {
            result = try await CommandExecutor.run(
                brewURL,
                arguments: arguments,
                environment: environment,
                timeout: .seconds(600), // 10 minutes for installation
                captureLimitBytes: mutatingOutputCaptureLimitBytes
            )
        } catch {
            throw mapExecutionError(error)
        }

        try ensureNotCancelled(result)

        guard result.isSuccess else {
            logger.error("brew install failed: \(result.stderr)")
            throw AppError.brewFailed(exitCode: result.exitCode, stderr: result.stderr)
        }

        logger.info("Successfully installed \(packageName)")
    }

    /// Resolves package type before installation to avoid cask-only packages being treated as formulae.
    private func resolveInstallType(
        packageName: String,
        preferredType: PackageType,
        debugMode: Bool
    ) async throws -> PackageType {
        let brewURL = try await ensureBrewURL()
        let arguments = BrewPackagesArgumentsBuilder.infoArguments(
            packageName: packageName,
            type: nil,
            debugMode: debugMode
        )

        let result: CommandResult
        do {
            result = try await CommandExecutor.run(
                brewURL,
                arguments: arguments,
                environment: environment,
                timeout: .seconds(20)
            )
        } catch {
            throw mapExecutionError(error)
        }

        try ensureNotCancelled(result)

        guard result.isSuccess else {
            // Preserve previous behavior if we cannot resolve package type.
            return preferredType
        }

        do {
            let response = try BrewInfoResponse.decode(from: result.stdout)
            let hasFormula = !response.formulae.isEmpty
            let hasCask = !response.casks.isEmpty

            if hasFormula && !hasCask {
                return .formula
            }

            if hasCask && !hasFormula {
                return .cask
            }

            return preferredType
        } catch {
            return preferredType
        }
    }

    // MARK: - Decoding

    /// Decodes installed packages from JSON output.
    ///
    /// Parses the JSON response from `brew info --json=v2 --installed` and
    /// converts both formulae and casks into a unified BrewPackage array.
    ///
    /// - Parameter jsonString: The JSON string from brew command output.
    /// - Returns: An array of installed packages.
    /// - Throws: `AppError.jsonDecodingFailed` if parsing fails.
    private func decodeInstalledPackages(from jsonString: String) throws -> [BrewPackage] {
        let response: BrewInfoResponse
        do {
            response = try BrewInfoResponse.decode(from: jsonString)

            // Convert formulae (command-line tools) to unified package model
            let formulae = response.formulae.compactMap { formula -> BrewPackage? in
                guard let installedVersion = formula.installed?.first?.version else { return nil }

                return BrewPackage(
                    name: formula.name,
                    fullName: formula.fullName,
                    desc: formula.desc,
                    homepage: formula.homepage,
                    type: .formula,
                    installedVersion: installedVersion,
                    currentVersion: formula.versions.stable,
                    isOutdated: formula.outdated ?? false,
                    pinnedVersion: formula.pinned == true ? installedVersion : nil,
                    tap: formula.tap
                )
            }

            // Convert casks (GUI applications) to unified package model
            let casks = response.casks.compactMap { cask -> BrewPackage? in
                guard let installedVersion = cask.installed else { return nil }

                return BrewPackage(
                    name: cask.token,
                    fullName: cask.token,
                    desc: cask.desc,
                    homepage: cask.homepage,
                    type: .cask,
                    installedVersion: installedVersion,
                    currentVersion: cask.version,
                    isOutdated: cask.outdated ?? false,
                    pinnedVersion: nil,
                    tap: cask.tap
                )
            }

            return formulae + casks
        } catch {
            logger.error("JSON decoding failed: \(error.localizedDescription)")
            throw AppError.jsonDecodingFailed(rawOutput: jsonString, underlyingErrorDescription: error.localizedDescription)
        }
    }

    /// Decodes outdated package names from JSON output.
    ///
    /// Parses the JSON response from `brew outdated --json=v2` and extracts
    /// package names for both formulae and casks.
    ///
    /// - Parameter jsonString: The JSON string from brew command output.
    /// - Returns: An array of outdated package names.
    /// - Throws: `AppError.jsonDecodingFailed` if parsing fails.
    private func decodeOutdatedPackages(from jsonString: String) throws -> [String] {
        let response: BrewOutdatedResponse
        do {
            response = try BrewOutdatedResponse.decode(from: jsonString)

            let formulaeNames = response.formulae.map { $0.name }
            let caskNames = response.casks.map { $0.token ?? $0.name }

            return formulaeNames + caskNames
        } catch {
            logger.error("JSON decoding failed: \(error.localizedDescription)")
            throw AppError.jsonDecodingFailed(rawOutput: jsonString, underlyingErrorDescription: error.localizedDescription)
        }
    }

    /// Decodes detailed package information from JSON output.
    ///
    /// Parses the JSON response from `brew info --json=v2 <package>` and converts
    /// it to a BrewPackageInfo structure. Handles both formulae and casks.
    ///
    /// - Parameter jsonString: The JSON string from brew command output.
    /// - Returns: Detailed information about the package.
    /// - Throws: `AppError.jsonDecodingFailed` if parsing fails or no package found.
    private func decodePackageInfo(from jsonString: String) throws -> BrewPackageInfo {
        let response: BrewInfoResponse
        do {
            response = try BrewInfoResponse.decode(from: jsonString)

            if let formula = response.formulae.first {
                return BrewPackageInfo(
                    name: formula.name,
                    fullName: formula.fullName,
                    desc: formula.desc,
                    homepage: formula.homepage,
                    license: formula.license,
                    versions: BrewPackageInfo.Versions(
                        stable: formula.versions.stable,
                        head: formula.versions.head,
                        bottle: formula.versions.bottle
                    ),
                    urls: formula.urls.map { urls in
                        BrewPackageInfo.URLs(
                            stable: urls.stable.map { BrewPackageInfo.URLs.StableURL(url: $0.url) },
                            head: urls.head.map { BrewPackageInfo.URLs.HeadURL(url: $0.url) }
                        )
                    },
                    installedVersions: formula.installed?.map { installed in
                        BrewPackageInfo.InstalledVersion(
                            version: installed.version,
                            installedOnRequest: installed.installedOnRequest,
                            installedAsDepency: installed.installedAsDepency
                        )
                    },
                    linkedKeg: formula.linkedKeg,
                    outdated: formula.outdated
                )
            } else if let cask = response.casks.first {
                return BrewPackageInfo(
                    name: cask.token,
                    fullName: cask.token,
                    desc: cask.desc,
                    homepage: cask.homepage,
                    license: nil,
                    versions: BrewPackageInfo.Versions(stable: cask.version, head: nil, bottle: nil),
                    urls: nil,
                    installedVersions: cask.installed.map { version in
                        [BrewPackageInfo.InstalledVersion(version: version, installedOnRequest: nil, installedAsDepency: nil)]
                    },
                    linkedKeg: nil,
                    outdated: cask.outdated
                )
            } else {
                throw AppError.jsonDecodingFailed(
                    rawOutput: jsonString,
                    underlyingErrorDescription: "No formula or cask found in response"
                )
            }
        } catch let error as AppError {
            throw error
        } catch {
            logger.error("JSON decoding failed: \(error.localizedDescription)")
            throw AppError.jsonDecodingFailed(rawOutput: jsonString, underlyingErrorDescription: error.localizedDescription)
        }
    }
}
