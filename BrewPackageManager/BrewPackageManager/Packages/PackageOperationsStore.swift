//
//  PackageOperationsStore.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation
import Observation
import OSLog

/// Ejecuta las operaciones que mutan paquetes instalados.
///
/// Gestiona la selección para el upgrade masivo (con progreso y manejo de
/// paquetes pineados), la desinstalación individual y la carga del detalle
/// de un paquete. Tras cada operación que cambia el sistema fuerza un
/// refresco del catálogo e invalida la caché de dependencias.
@MainActor
@Observable
final class PackageOperationsStore {

    // MARK: - Nested Types

    /// Progress information for bulk upgrade operations.
    struct UpgradeProgress: Sendable {
        /// Number of packages that have completed (successfully or with error).
        let completed: Int

        /// Total number of packages to upgrade.
        let total: Int

        /// The name of the package currently being upgraded.
        let currentPackage: String?

        /// Number of packages that failed to upgrade.
        let failed: Int
    }

    // MARK: - Properties

    /// Logger for tracking store operations and debugging.
    private let logger = Logger(subsystem: "BrewPackageManager", category: "PackageOperationsStore")

    /// Catálogo que aporta el snapshot de paquetes y el estado de pines.
    private let catalog: PackagesCatalogStore

    /// Visibilidad que decide qué actualizaciones son accionables.
    private let visibility: PackageVisibilityStore

    /// Client for executing Homebrew package commands.
    private let client: BrewPackagesClientProtocol

    /// Canal para errores que la UI muestra como banner no fatal.
    @ObservationIgnored var reportError: ((AppError) -> Void)?

    /// Package IDs that are currently selected for bulk updates.
    var selectedPackageIDs: Set<String> = []

    /// Tracks the status of operations for individual packages.
    var packageOperations: [String: PackageOperation] = [:]

    /// Whether a bulk upgrade operation is currently in progress.
    var isUpgradingSelected = false

    /// Progress information for the current bulk upgrade operation.
    var upgradeProgress: UpgradeProgress?

    /// Detailed information about a selected package, if loaded.
    private(set) var selectedPackageInfo: BrewPackageInfo?

    // MARK: - Initialization

    /// Crea el store de operaciones con sus dependencias.
    ///
    /// - Parameters:
    ///   - catalog: Catálogo de paquetes instalados y pines.
    ///   - visibility: Reglas de visibilidad de actualizaciones.
    ///   - client: Cliente de comandos de Homebrew.
    init(
        catalog: PackagesCatalogStore,
        visibility: PackageVisibilityStore,
        client: BrewPackagesClientProtocol
    ) {
        self.catalog = catalog
        self.visibility = visibility
        self.client = client
    }

    // MARK: - Selection

    /// Toggles selection state for a package.
    ///
    /// - Parameter packageID: The ID of the package to toggle.
    func toggleSelection(for packageID: String) {
        guard let package = catalog.packages.first(where: { $0.id == packageID }), visibility.hasVisibleUpdate(package) else {
            selectedPackageIDs.remove(packageID)
            return
        }

        if selectedPackageIDs.contains(packageID) {
            selectedPackageIDs.remove(packageID)
        } else {
            selectedPackageIDs.insert(packageID)
        }
    }

    /// Selects all packages that have updates available.
    func selectAllOutdated() {
        selectedPackageIDs = Set(visibility.visibleOutdatedPackages.map(\.id))
    }

    /// Deselects all packages.
    func deselectAll() {
        selectedPackageIDs.removeAll()
    }

    /// Retira un paquete concreto de la selección activa.
    func deselect(packageID: String) {
        selectedPackageIDs.remove(packageID)
    }

    /// Purga selecciones que ya no corresponden a actualizaciones visibles.
    func reconcileSelection(with packages: [BrewPackage]) {
        let visibleUpdateIDs = Set(packages.filter { visibility.hasVisibleUpdate($0) }.map(\.id))
        selectedPackageIDs.formIntersection(visibleUpdateIDs)
    }

    // MARK: - Upgrade

    /// Upgrades all selected packages.
    ///
    /// This method upgrades packages sequentially, tracking progress and handling errors
    /// for each package. After completion, it refreshes the package list and clears
    /// selections if all upgrades succeeded.
    ///
    /// - Parameter debugMode: Whether to run commands in debug mode with verbose output.
    func upgradeSelected(debugMode: Bool = false) async {
        guard !isUpgradingSelected else { return }

        let selectedPackages = catalog.packages.filter {
            selectedPackageIDs.contains($0.id) && !visibility.isPackageHidden($0) && !visibility.isUpdateHidden($0)
        }
        guard !selectedPackages.isEmpty else { return }

        let pinnedNames = await catalog.refreshPinnedFormulaNames(debugMode: debugMode)
        let pinnedPackages = selectedPackages.filter { catalog.isPackagePinned($0, pinnedNames: pinnedNames) }
        let upgradablePackages = selectedPackages.filter { !catalog.isPackagePinned($0, pinnedNames: pinnedNames) }

        if !pinnedPackages.isEmpty {
            for package in pinnedPackages {
                let message = "Package '\(package.name)' is pinned. Run 'brew unpin \(package.name)' to upgrade."
                packageOperations[package.id] = PackageOperation(
                    status: .failed,
                    error: .unknown(message),
                    diagnostics: message
                )
                logHistory(operation: .upgrade, packageName: package.name, details: message, success: false)
            }
        }

        if upgradablePackages.isEmpty {
            if !pinnedPackages.isEmpty {
                let names = pinnedPackages.map(\.name).sorted().joined(separator: ", ")
                report(.unknown("Selected package(s) are pinned: \(names). Use 'brew unpin <name>' and try again."))
            }
            return
        }

        logger.info("Upgrading \(upgradablePackages.count) selected packages")

        isUpgradingSelected = true
        upgradeProgress = UpgradeProgress(completed: 0, total: upgradablePackages.count, currentPackage: nil, failed: 0)

        var completed = 0
        var failed = 0
        var firstFailure: AppError?

        for package in upgradablePackages {
            upgradeProgress = UpgradeProgress(
                completed: completed,
                total: upgradablePackages.count,
                currentPackage: package.name,
                failed: failed
            )

            packageOperations[package.id] = PackageOperation(status: .running, error: nil, diagnostics: nil)

            do {
                try await client.upgradePackage(package.name, type: package.type, debugMode: debugMode)
                packageOperations[package.id] = PackageOperation(status: .succeeded, error: nil, diagnostics: nil)
                logHistory(operation: .upgrade, packageName: package.name, success: true)
            } catch let error as AppError {
                if case .cancelled = error {
                    logger.debug("Upgrade cancelled")
                    packageOperations[package.id] = .idle
                    logHistory(operation: .upgrade, packageName: package.name, details: "Operation cancelled", success: false)
                    break
                }
                let mappedError = mapUpgradeError(error, packageName: package.name)
                failed += 1
                if firstFailure == nil {
                    firstFailure = mappedError
                }
                packageOperations[package.id] = PackageOperation(
                    status: .failed,
                    error: mappedError,
                    diagnostics: "Failed to upgrade \(package.name): \(mappedError.localizedDescription)"
                )
                logHistory(operation: .upgrade, packageName: package.name, details: mappedError.localizedDescription, success: false)
            } catch {
                failed += 1
                let appError = AppError.brewFailed(exitCode: -1, stderr: error.localizedDescription)
                if firstFailure == nil {
                    firstFailure = appError
                }
                packageOperations[package.id] = PackageOperation(
                    status: .failed,
                    error: appError,
                    diagnostics: "Failed to upgrade \(package.name): \(error.localizedDescription)"
                )
                logHistory(operation: .upgrade, packageName: package.name, details: error.localizedDescription, success: false)
            }

            completed += 1
        }

        upgradeProgress = UpgradeProgress(
            completed: completed,
            total: upgradablePackages.count,
            currentPackage: nil,
            failed: failed
        )

        isUpgradingSelected = false
        upgradeProgress = nil

        // Clear selections after successful upgrade
        if failed == 0 {
            deselectAll()
        } else if let firstFailure {
            report(firstFailure)
        }

        if !pinnedPackages.isEmpty, failed == 0 {
            let names = pinnedPackages.map(\.name).sorted().joined(separator: ", ")
            report(.unknown("Skipped pinned package(s): \(names). Use 'brew unpin <name>' to upgrade."))
        }

        // Refresh in background so the UI does not appear stuck in an updating state.
        Task {
            await catalog.refresh(debugMode: debugMode, force: true)
        }
    }

    // MARK: - Uninstall

    /// Uninstalls a package.
    ///
    /// This method removes the specified package and refreshes the package list
    /// upon successful completion.
    ///
    /// - Parameters:
    ///   - packageID: The ID of the package to uninstall.
    ///   - debugMode: Whether to run commands in debug mode with verbose output.
    func uninstallPackage(_ packageID: String, debugMode: Bool = false) async {
        guard let package = catalog.packages.first(where: { $0.id == packageID }) else { return }

        logger.info("Uninstalling package \(package.name)")

        packageOperations[packageID] = PackageOperation(status: .running, error: nil, diagnostics: nil)

        do {
            try await client.uninstallPackage(package.name, type: package.type, debugMode: debugMode)
            packageOperations[packageID] = PackageOperation(status: .succeeded, error: nil, diagnostics: nil)
            logHistory(operation: .uninstall, packageName: package.name, success: true)
            // El grafo de dependencias ha cambiado: la caché deja de valer.
            DependenciesStore.invalidateCache()

            // Refresh to update package list
            await catalog.refresh(debugMode: debugMode, force: true)

            // Clear the operation status after refresh
            packageOperations.removeValue(forKey: packageID)
        } catch let error as AppError {
            if case .cancelled = error {
                logger.debug("Uninstall cancelled")
                packageOperations[packageID] = .idle
                return
            }
            packageOperations[packageID] = PackageOperation(
                status: .failed,
                error: error,
                diagnostics: "Failed to uninstall \(package.name): \(error.localizedDescription)"
            )
            logHistory(operation: .uninstall, packageName: package.name, details: error.localizedDescription, success: false)
        } catch {
            let appError = AppError.brewFailed(exitCode: -1, stderr: error.localizedDescription)
            packageOperations[packageID] = PackageOperation(
                status: .failed,
                error: appError,
                diagnostics: "Failed to uninstall \(package.name): \(error.localizedDescription)"
            )
            logHistory(operation: .uninstall, packageName: package.name, details: error.localizedDescription, success: false)
        }
    }

    // MARK: - Package Detail

    /// Fetches detailed information about a package.
    ///
    /// The fetched information is stored in `selectedPackageInfo` for display.
    ///
    /// - Parameters:
    ///   - packageName: The name of the package to query.
    ///   - type: Optional package type to disambiguate formula vs cask names.
    ///   - debugMode: Whether to run commands in debug mode with verbose output.
    func fetchPackageInfo(_ packageName: String, type: PackageType? = nil, debugMode: Bool = false) async {
        logger.info("Fetching info for \(packageName)")

        // Se limpia antes de la petición: si esta falla, la vista no debe
        // poder navegar con la información de una consulta anterior.
        selectedPackageInfo = nil

        do {
            selectedPackageInfo = try await client.getPackageInfo(packageName, type: type, debugMode: debugMode)
            logger.info("Fetched info for \(packageName)")
        } catch let error as AppError {
            if case .cancelled = error {
                logger.debug("Fetch info cancelled")
                return
            }
            report(error)
        } catch {
            report(.brewFailed(exitCode: -1, stderr: error.localizedDescription))
            logger.error("Fetch info failed: \(error.localizedDescription)")
        }
    }

    /// Clears the selected package information.
    func clearPackageInfo() {
        selectedPackageInfo = nil
    }

    // MARK: - Private Methods

    /// Emite un error no fatal hacia la raíz, con red de seguridad si el
    /// cableado falta: en debug detiene la ejecución y en release deja traza.
    private func report(_ error: AppError) {
        guard let reportError else {
            logger.fault("reportError sin cablear: se pierde \(error.localizedDescription)")
            assertionFailure("PackageOperationsStore usado fuera de PackagesStore")
            return
        }
        reportError(error)
    }

    private func mapUpgradeError(_ error: AppError, packageName: String) -> AppError {
        guard case .brewFailed(_, let stderr) = error else { return error }
        guard isPinnedUpgradeFailure(stderr) else { return error }
        return .unknown("Package '\(packageName)' is pinned. Run 'brew unpin \(packageName)' and try again.")
    }

    private func isPinnedUpgradeFailure(_ stderr: String) -> Bool {
        let message = stderr.lowercased()
        return message.contains("not upgrading") && message.contains("pinned")
    }

    /// Logs an operation to history without blocking UI flow.
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
