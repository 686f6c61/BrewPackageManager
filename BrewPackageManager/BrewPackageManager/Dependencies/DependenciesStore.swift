//
//  DependenciesStore.swift
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

/// Store for managing package dependencies state.
///
/// This observable store coordinates fetching dependency information
/// for installed packages.
@MainActor
@Observable
final class DependenciesStore {

    // MARK: - Properties

    /// All package dependencies.
    var dependencies: [DependencyInfo] = []

    /// Currently selected package for detail view.
    var selectedPackage: DependencyInfo?

    /// Whether the store is currently loading dependencies.
    var isLoading = false

    /// The last error that occurred.
    var lastError: AppError?

    /// Logger for dependencies store operations.
    private let logger = Logger(subsystem: "BrewPackageManager", category: "DependenciesStore")

    /// Dependencies client for executing commands.
    private let client = DependenciesClient()

    // MARK: - Computed Properties

    /// Packages with no dependencies.
    var independentPackages: [DependencyInfo] {
        dependencies.filter { !$0.hasDependencies }
    }

    /// Packages that are required by others.
    var requiredPackages: [DependencyInfo] {
        dependencies.filter { $0.isRequired }
    }

    /// Total number of dependencies across all packages.
    var totalDependencies: Int {
        dependencies.reduce(0) { $0 + $1.dependencyCount }
    }

    // MARK: - Public Methods

    /// Fetch dependencies for all installed packages.
    func fetchAllDependencies() async {
        guard !isLoading else { return }

        isLoading = true
        lastError = nil

        logger.info("Fetching all dependencies")

        do {
            let allDeps = try await client.fetchAllDependencies()
            dependencies = allDeps.sorted { $0.packageName < $1.packageName }
            logger.info("Successfully fetched dependencies for \(allDeps.count) packages")
        } catch let error as AppError {
            logger.error("Failed to fetch dependencies: \(error.localizedDescription)")
            lastError = error
        } catch {
            logger.error("Unexpected error fetching dependencies: \(error.localizedDescription)")
            lastError = AppError.unknown(error.localizedDescription)
        }

        isLoading = false
    }

    /// Fetch dependencies for a specific package.
    ///
    /// - Parameter packageName: The package name.
    func fetchDependencies(for packageName: String) async {
        guard !isLoading else { return }

        isLoading = true
        lastError = nil

        logger.info("Fetching dependencies for: \(packageName)")

        do {
            let depInfo = try await client.fetchDependencies(for: packageName)
            selectedPackage = depInfo
            logger.info("Successfully fetched dependencies for \(packageName)")
        } catch let error as AppError {
            logger.error("Failed to fetch dependencies for \(packageName): \(error.localizedDescription)")
            lastError = error
        } catch {
            logger.error("Unexpected error: \(error.localizedDescription)")
            lastError = AppError.unknown(error.localizedDescription)
        }

        isLoading = false
    }

    /// Fetch reverse dependencies (what uses this package).
    ///
    /// - Parameter packageName: The package name.
    /// - Returns: Array of package names that depend on this package.
    func fetchUsedBy(packageName: String) async -> [String] {
        do {
            return try await client.fetchUsedBy(packageName: packageName)
        } catch {
            logger.error("Failed to fetch reverse dependencies: \(error.localizedDescription)")
            return []
        }
    }
}
