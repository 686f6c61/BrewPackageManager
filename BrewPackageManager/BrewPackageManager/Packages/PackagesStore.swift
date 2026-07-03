//
//  PackagesStore.swift
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

/// Raíz de composición del dominio de paquetes.
///
/// Crea y cablea los sub-stores especializados y posee el único estado
/// transversal: el error no fatal que la UI muestra como banner. Cada
/// responsabilidad vive en su sub-store:
///
/// - `catalog`: refresco, caché de disco y pines (`PackagesCatalogStore`).
/// - `visibility`: paquetes y actualizaciones ocultos (`PackageVisibilityStore`).
/// - `operations`: selección, upgrade, desinstalación y detalle (`PackageOperationsStore`).
/// - `search`: búsqueda e instalación (`PackageSearchStore`).
/// - `appUpdates`: versiones de la propia app (`AppUpdateStore`).
///
/// La orquestación cruzada queda explícita en el `init`: tras cada snapshot
/// del catálogo se reconcilia primero la visibilidad y después la selección
/// (que depende de ella), y al ocultar un elemento se limpia su selección.
///
/// All methods must be called on the main actor as this class updates SwiftUI state.
@MainActor
@Observable
final class PackagesStore {

    // MARK: - Sub-stores

    /// Sub-store del catálogo: refresco, caché de disco y pines.
    let catalog: PackagesCatalogStore

    /// Sub-store de visibilidad: paquetes y actualizaciones ocultos.
    let visibility: PackageVisibilityStore

    /// Sub-store de operaciones: selección, upgrade, desinstalación y detalle.
    let operations: PackageOperationsStore

    /// Sub-store de búsqueda e instalación de paquetes nuevos.
    let search: PackageSearchStore

    /// Sub-store de actualizaciones de la propia aplicación.
    let appUpdates = AppUpdateStore()

    // MARK: - Cross-cutting State

    /// Non-fatal errors that don't prevent showing cached data.
    var nonFatalError: AppError?

    // MARK: - Initialization

    /// Initializes the store with a Homebrew client.
    ///
    /// - Parameters:
    ///   - client: The client to use for Homebrew operations. Defaults to a new BrewPackagesClient.
    ///   - defaults: The defaults store to use for visibility preferences. Defaults to `.standard`.
    init(
        client: BrewPackagesClientProtocol = BrewPackagesClient(),
        defaults: UserDefaults = .standard
    ) {
        let catalog = PackagesCatalogStore(client: client)
        let visibility = PackageVisibilityStore(catalog: catalog, defaults: defaults)
        self.catalog = catalog
        self.visibility = visibility
        self.operations = PackageOperationsStore(catalog: catalog, visibility: visibility, client: client)
        self.search = PackageSearchStore(catalog: catalog, client: client)

        // Cableado: el catálogo publica snapshots y errores; la raíz reconcilia
        // primero la visibilidad y después la selección, que depende de ella.
        catalog.onPackagesReplaced = { [weak self] packages in
            self?.visibility.reconcile(with: packages)
            self?.operations.reconcileSelection(with: packages)
        }
        catalog.visibleUpdatesProvider = { [weak self] in
            // Devuelve nil si la raíz ya no existe: el catálogo degradará el
            // histórico al total sin filtrar, etiquetado, en vez de un 0 falso.
            self?.visibility.visibleOutdatedCount
        }
        visibility.onPackageHidden = { [weak self] packageID in
            self?.operations.deselect(packageID: packageID)
        }

        let reportError: (AppError) -> Void = { [weak self] error in
            self?.nonFatalError = error
        }
        catalog.reportError = reportError
        operations.reportError = reportError
        search.reportError = reportError
    }

    // MARK: - Public Methods

    /// Dismisses the current non-fatal error.
    func dismissError() {
        nonFatalError = nil
    }

    /// Exports the package list to CSV format.
    ///
    /// The CSV includes columns for name, full name, type, versions, outdated status,
    /// tap, description, and homepage. Fields containing commas or quotes are properly escaped.
    ///
    /// - Returns: A CSV-formatted string of all packages.
    func exportToCSV() -> String {
        PackageListCSVExporter.csv(from: catalog.packages)
    }
}
