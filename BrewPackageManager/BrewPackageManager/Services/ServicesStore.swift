//
//  ServicesStore.swift
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

/// Store for managing Homebrew services state.
///
/// This observable store coordinates fetching services data and
/// performing start/stop/restart operations.
@MainActor
@Observable
final class ServicesStore {

    // MARK: - Properties

    /// All available Homebrew services.
    var services: [BrewService] = []

    /// Whether the store is currently loading services.
    var isLoading = false

    /// Whether a service operation is in progress.
    var isOperating = false

    /// The last error that occurred.
    var lastError: AppError?

    /// Logger for services store operations.
    private let logger = Logger(subsystem: "BrewPackageManager", category: "ServicesStore")

    /// Services client for executing commands.
    private let client = ServicesClient()

    // MARK: - Computed Properties

    /// Running services count.
    var runningCount: Int {
        services.filter { $0.status == .started }.count
    }

    /// Stopped services count.
    var stoppedCount: Int {
        services.filter { $0.status == .stopped }.count
    }

    // MARK: - Public Methods

    /// Fetch all services from Homebrew.
    func fetchServices() async {
        guard !isLoading else { return }

        isLoading = true
        lastError = nil

        logger.info("Fetching services")

        do {
            let fetchedServices = try await client.fetchServices()
            services = fetchedServices.sorted { $0.name < $1.name }
            logger.info("Successfully fetched \(fetchedServices.count) services")
        } catch let error as AppError {
            if case .cancelled = error {
                logger.debug("Services fetch cancelled")
                isLoading = false
                return
            }
            logger.error("Failed to fetch services: \(error.localizedDescription)")
            lastError = error
        } catch {
            logger.error("Unexpected error fetching services: \(error.localizedDescription)")
            lastError = AppError.unknown(error.localizedDescription)
        }

        isLoading = false
    }

    /// Start a service.
    ///
    /// - Parameter service: The service to start.
    func startService(_ service: BrewService) async {
        guard !isOperating else { return }

        isOperating = true
        lastError = nil

        logger.info("Starting service: \(service.name)")

        do {
            try await client.startService(service.name)
            logger.info("Service \(service.name) started successfully")
            logHistory(operation: .serviceStart, packageName: service.name, success: true)

            // Refresh services list after operation
            await fetchServices()
        } catch let error as AppError {
            if case .cancelled = error {
                logger.debug("Start service cancelled: \(service.name)")
                isOperating = false
                return
            }
            logger.error("Failed to start service \(service.name): \(error.localizedDescription)")
            lastError = error
            logHistory(operation: .serviceStart, packageName: service.name, details: error.localizedDescription, success: false)
        } catch {
            logger.error("Unexpected error starting service \(service.name): \(error.localizedDescription)")
            lastError = AppError.unknown(error.localizedDescription)
            logHistory(operation: .serviceStart, packageName: service.name, details: error.localizedDescription, success: false)
        }

        isOperating = false
    }

    /// Stop a service.
    ///
    /// - Parameter service: The service to stop.
    func stopService(_ service: BrewService) async {
        guard !isOperating else { return }

        isOperating = true
        lastError = nil

        logger.info("Stopping service: \(service.name)")

        do {
            try await client.stopService(service.name)
            logger.info("Service \(service.name) stopped successfully")
            logHistory(operation: .serviceStop, packageName: service.name, success: true)

            // Refresh services list after operation
            await fetchServices()
        } catch let error as AppError {
            if case .cancelled = error {
                logger.debug("Stop service cancelled: \(service.name)")
                isOperating = false
                return
            }
            logger.error("Failed to stop service \(service.name): \(error.localizedDescription)")
            lastError = error
            logHistory(operation: .serviceStop, packageName: service.name, details: error.localizedDescription, success: false)
        } catch {
            logger.error("Unexpected error stopping service \(service.name): \(error.localizedDescription)")
            lastError = AppError.unknown(error.localizedDescription)
            logHistory(operation: .serviceStop, packageName: service.name, details: error.localizedDescription, success: false)
        }

        isOperating = false
    }

    /// Restart a service.
    ///
    /// - Parameter service: The service to restart.
    func restartService(_ service: BrewService) async {
        guard !isOperating else { return }

        isOperating = true
        lastError = nil

        logger.info("Restarting service: \(service.name)")

        do {
            try await client.restartService(service.name)
            logger.info("Service \(service.name) restarted successfully")
            logHistory(operation: .serviceRestart, packageName: service.name, success: true)

            // Refresh services list after operation
            await fetchServices()
        } catch let error as AppError {
            if case .cancelled = error {
                logger.debug("Restart service cancelled: \(service.name)")
                isOperating = false
                return
            }
            logger.error("Failed to restart service \(service.name): \(error.localizedDescription)")
            lastError = error
            logHistory(operation: .serviceRestart, packageName: service.name, details: error.localizedDescription, success: false)
        } catch {
            logger.error("Unexpected error restarting service \(service.name): \(error.localizedDescription)")
            lastError = AppError.unknown(error.localizedDescription)
            logHistory(operation: .serviceRestart, packageName: service.name, details: error.localizedDescription, success: false)
        }

        isOperating = false
    }

    private func logHistory(
        operation: HistoryEntry.OperationType,
        packageName: String,
        details: String? = nil,
        success: Bool = true
    ) {
        Task {
            await HistoryStore.logOperation(
                operation: operation,
                packageName: packageName,
                details: details,
                success: success
            )
        }
    }
}
