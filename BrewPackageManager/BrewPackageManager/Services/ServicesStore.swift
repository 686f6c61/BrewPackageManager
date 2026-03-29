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

    enum ServiceAction: String, Sendable {
        case refresh
        case start
        case stop
        case restart

        var displayName: String {
            rawValue.capitalized
        }
    }

    enum ServiceOperationState {
        case idle
        case running(ServiceAction)
        case succeeded(ServiceAction, message: String)
        case failed(ServiceAction, AppError)
    }

    // MARK: - Properties

    /// All available Homebrew services.
    var services: [BrewService] = []

    /// Whether the store is currently loading services.
    var isLoading = false

    /// Current per-service operation states.
    var serviceOperations: [String: ServiceOperationState] = [:]

    /// Status message from the most recent refresh or mutation.
    var statusMessage: String?

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

    /// Whether a refresh is already in progress.
    var isRefreshing: Bool {
        isLoading
    }

    /// Returns the current operation state for a service.
    func operationState(for serviceID: String) -> ServiceOperationState {
        serviceOperations[serviceID] ?? .idle
    }

    /// Whether a specific service is currently performing an operation.
    func isOperating(_ serviceID: String) -> Bool {
        if case .running = operationState(for: serviceID) {
            return true
        }
        return false
    }

    // MARK: - Public Methods

    /// Fetch all services from Homebrew.
    func fetchServices(showStatusMessage: Bool = false) async {
        guard !isLoading else { return }

        isLoading = true
        lastError = nil
        if showStatusMessage {
            statusMessage = "Refreshing services..."
        }

        logger.info("Fetching services")

        do {
            let fetchedServices = try await client.fetchServices()
            services = fetchedServices.sorted { $0.name < $1.name }
            if showStatusMessage {
                statusMessage = "Loaded \(fetchedServices.count) services."
            }
            logger.info("Successfully fetched \(fetchedServices.count) services")
        } catch let error as AppError {
            if case .cancelled = error {
                logger.debug("Services fetch cancelled")
                isLoading = false
                return
            }
            logger.error("Failed to fetch services: \(error.localizedDescription)")
            lastError = error
            statusMessage = nil
        } catch {
            logger.error("Unexpected error fetching services: \(error.localizedDescription)")
            lastError = AppError.unknown(error.localizedDescription)
            statusMessage = nil
        }

        isLoading = false
    }

    /// Start a service.
    ///
    /// - Parameter service: The service to start.
    func startService(_ service: BrewService) async {
        guard !isOperating(service.id) else { return }

        lastError = nil
        serviceOperations[service.id] = .running(.start)

        logger.info("Starting service: \(service.name)")

        do {
            try await client.startService(service.name)
            logger.info("Service \(service.name) started successfully")
            serviceOperations[service.id] = .succeeded(.start, message: "Started \(service.name).")
            statusMessage = "Started \(service.name)."
            logHistory(operation: .serviceStart, packageName: service.name, success: true)

            // Refresh services list after operation
            await fetchServices()
        } catch let error as AppError {
            if case .cancelled = error {
                logger.debug("Start service cancelled: \(service.name)")
                serviceOperations[service.id] = .idle
                return
            }
            logger.error("Failed to start service \(service.name): \(error.localizedDescription)")
            lastError = error
            serviceOperations[service.id] = .failed(.start, error)
            statusMessage = nil
            logHistory(operation: .serviceStart, packageName: service.name, details: error.localizedDescription, success: false)
        } catch {
            logger.error("Unexpected error starting service \(service.name): \(error.localizedDescription)")
            let appError = AppError.unknown(error.localizedDescription)
            lastError = appError
            serviceOperations[service.id] = .failed(.start, appError)
            statusMessage = nil
            logHistory(operation: .serviceStart, packageName: service.name, details: error.localizedDescription, success: false)
        }
    }

    /// Stop a service.
    ///
    /// - Parameter service: The service to stop.
    func stopService(_ service: BrewService) async {
        guard !isOperating(service.id) else { return }

        lastError = nil
        serviceOperations[service.id] = .running(.stop)

        logger.info("Stopping service: \(service.name)")

        do {
            try await client.stopService(service.name)
            logger.info("Service \(service.name) stopped successfully")
            serviceOperations[service.id] = .succeeded(.stop, message: "Stopped \(service.name).")
            statusMessage = "Stopped \(service.name)."
            logHistory(operation: .serviceStop, packageName: service.name, success: true)

            // Refresh services list after operation
            await fetchServices()
        } catch let error as AppError {
            if case .cancelled = error {
                logger.debug("Stop service cancelled: \(service.name)")
                serviceOperations[service.id] = .idle
                return
            }
            logger.error("Failed to stop service \(service.name): \(error.localizedDescription)")
            lastError = error
            serviceOperations[service.id] = .failed(.stop, error)
            statusMessage = nil
            logHistory(operation: .serviceStop, packageName: service.name, details: error.localizedDescription, success: false)
        } catch {
            logger.error("Unexpected error stopping service \(service.name): \(error.localizedDescription)")
            let appError = AppError.unknown(error.localizedDescription)
            lastError = appError
            serviceOperations[service.id] = .failed(.stop, appError)
            statusMessage = nil
            logHistory(operation: .serviceStop, packageName: service.name, details: error.localizedDescription, success: false)
        }
    }

    /// Restart a service.
    ///
    /// - Parameter service: The service to restart.
    func restartService(_ service: BrewService) async {
        guard !isOperating(service.id) else { return }

        lastError = nil
        serviceOperations[service.id] = .running(.restart)

        logger.info("Restarting service: \(service.name)")

        do {
            try await client.restartService(service.name)
            logger.info("Service \(service.name) restarted successfully")
            serviceOperations[service.id] = .succeeded(.restart, message: "Restarted \(service.name).")
            statusMessage = "Restarted \(service.name)."
            logHistory(operation: .serviceRestart, packageName: service.name, success: true)

            // Refresh services list after operation
            await fetchServices()
        } catch let error as AppError {
            if case .cancelled = error {
                logger.debug("Restart service cancelled: \(service.name)")
                serviceOperations[service.id] = .idle
                return
            }
            logger.error("Failed to restart service \(service.name): \(error.localizedDescription)")
            lastError = error
            serviceOperations[service.id] = .failed(.restart, error)
            statusMessage = nil
            logHistory(operation: .serviceRestart, packageName: service.name, details: error.localizedDescription, success: false)
        } catch {
            logger.error("Unexpected error restarting service \(service.name): \(error.localizedDescription)")
            let appError = AppError.unknown(error.localizedDescription)
            lastError = appError
            serviceOperations[service.id] = .failed(.restart, appError)
            statusMessage = nil
            logHistory(operation: .serviceRestart, packageName: service.name, details: error.localizedDescription, success: false)
        }
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
