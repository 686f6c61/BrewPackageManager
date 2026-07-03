//
//  PackageSearchStore.swift
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

/// Búsqueda e instalación de paquetes nuevos desde Homebrew.
///
/// Mantiene el estado de búsqueda con un token monotónico que descarta
/// respuestas obsoletas cuando el usuario encadena consultas, y gestiona
/// las instalaciones con su progreso por paquete. Tras instalar fuerza un
/// refresco del catálogo e invalida la caché de dependencias.
@MainActor
@Observable
final class PackageSearchStore {

    // MARK: - Properties

    /// Logger for tracking store operations and debugging.
    private let logger = Logger(subsystem: "BrewPackageManager", category: "PackageSearchStore")

    /// Catálogo usado para marcar resultados ya instalados y refrescar tras instalar.
    private let catalog: PackagesCatalogStore

    /// Client for executing Homebrew package commands.
    private let client: BrewPackagesClientProtocol

    /// Canal para errores que la UI muestra como banner no fatal.
    @ObservationIgnored var reportError: ((AppError) -> Void)?

    /// The current search state.
    var state: SearchState = .idle

    /// Search results with package info loaded.
    private(set) var results: [SearchResult] = []

    /// Currently selected package type filter for search.
    var typeFilter: PackageType? = nil

    /// Packages currently being installed (keyed by package name).
    var installOperations: [String: PackageOperation] = [:]

    /// Number of results to show per page.
    private let searchPageSize = 15

    /// Monotonic token used to ignore stale search responses.
    private var activeSearchRequestID = 0

    // MARK: - Initialization

    /// Crea el store de búsqueda con sus dependencias.
    ///
    /// - Parameters:
    ///   - catalog: Catálogo de paquetes instalados.
    ///   - client: Cliente de comandos de Homebrew.
    init(catalog: PackagesCatalogStore, client: BrewPackagesClientProtocol) {
        self.catalog = catalog
        self.client = client
    }

    // MARK: - Search Operations

    /// Performs a package search.
    ///
    /// This method queries Homebrew for packages matching the given search term.
    /// Results are limited to the first page (15 results by default).
    ///
    /// - Parameters:
    ///   - query: The search term to query.
    ///   - debugMode: Whether to run in debug mode.
    func search(query: String, debugMode: Bool = false) async {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedQuery.isEmpty else {
            activeSearchRequestID += 1
            state = .idle
            results = []
            return
        }

        activeSearchRequestID += 1
        let requestID = activeSearchRequestID

        logger.info("Searching for packages: \(normalizedQuery)")
        state = .searching(query: normalizedQuery)

        do {
            let installedTypesByName = Dictionary(
                grouping: catalog.packages,
                by: { $0.name }
            ).mapValues { Set($0.map(\.type)) }

            let typedMatches: [(name: String, type: PackageType)]
            if let filter = typeFilter {
                let names = try await client.searchPackages(normalizedQuery, type: filter, debugMode: debugMode)
                typedMatches = names.map { (name: $0, type: filter) }
            } else {
                let formulaNames = try await client.searchPackages(normalizedQuery, type: .formula, debugMode: debugMode)
                let caskNames = try await client.searchPackages(normalizedQuery, type: .cask, debugMode: debugMode)

                var deduplicated: [(name: String, type: PackageType)] = []
                var seenKeys = Set<String>()

                for name in formulaNames {
                    let key = "\(PackageType.formula.rawValue):\(name)"
                    if seenKeys.insert(key).inserted {
                        deduplicated.append((name: name, type: .formula))
                    }
                }

                for name in caskNames {
                    let key = "\(PackageType.cask.rawValue):\(name)"
                    if seenKeys.insert(key).inserted {
                        deduplicated.append((name: name, type: .cask))
                    }
                }

                typedMatches = deduplicated
            }

            guard requestID == activeSearchRequestID else {
                logger.debug("Ignoring stale search results for query: \(normalizedQuery)")
                return
            }

            let hasMore = typedMatches.count > searchPageSize
            let pageMatches = Array(typedMatches.prefix(searchPageSize))

            results = pageMatches.map { match in
                let installedTypes = installedTypesByName[match.name] ?? []
                return SearchResult(
                    name: match.name,
                    type: match.type,
                    isInstalled: installedTypes.contains(match.type)
                )
            }

            state = .loaded(query: normalizedQuery, results: results, hasMore: hasMore)
            logger.info("Found \(typedMatches.count) packages (\(self.results.count) shown)")
            logHistory(
                operation: .search,
                packageName: normalizedQuery,
                details: "Found \(typedMatches.count) results",
                success: true
            )

        } catch let error as AppError {
            guard requestID == activeSearchRequestID else {
                logger.debug("Ignoring stale search error for query: \(normalizedQuery)")
                return
            }
            if case .cancelled = error {
                logger.debug("Search cancelled")
                state = .idle
                return
            }
            state = .error(error)
            logger.error("Search failed: \(error.localizedDescription)")
            logHistory(operation: .search, packageName: normalizedQuery, details: error.localizedDescription, success: false)
        } catch {
            guard requestID == activeSearchRequestID else {
                logger.debug("Ignoring stale search failure for query: \(normalizedQuery)")
                return
            }
            let appError = AppError.brewFailed(exitCode: -1, stderr: error.localizedDescription)
            state = .error(appError)
            logger.error("Search failed: \(error.localizedDescription)")
            logHistory(operation: .search, packageName: normalizedQuery, details: error.localizedDescription, success: false)
        }
    }

    /// Clears search results and resets to idle state.
    func clearSearch(resetFilter: Bool = false) {
        activeSearchRequestID += 1
        state = .idle
        results = []
        if resetFilter {
            typeFilter = nil
        }
    }

    /// Fetches detailed info for a search result.
    ///
    /// This method loads package information and caches it in the search result.
    ///
    /// - Parameters:
    ///   - result: The search result to fetch info for.
    ///   - debugMode: Whether to run in debug mode.
    func fetchSearchResultInfo(_ result: SearchResult, debugMode: Bool = false) async {
        guard let index = results.firstIndex(where: { $0.id == result.id }) else {
            return
        }

        // Skip if already loaded
        if results[index].info != nil {
            return
        }

        do {
            let info = try await client.getPackageInfo(result.name, type: result.type, debugMode: debugMode)
            results[index].info = info
        } catch let error as AppError {
            if case .cancelled = error {
                return
            }
            // El error debe llegar al estado observable: si solo se registra,
            // el botón «Details» parece no responder sin explicación.
            report(error)
            logger.error("Failed to fetch info for \(result.name): \(error.localizedDescription)")
        } catch {
            report(.brewFailed(exitCode: -1, stderr: error.localizedDescription))
            logger.error("Failed to fetch info for \(result.name): \(error.localizedDescription)")
        }
    }

    // MARK: - Installation Operations

    /// Installs a package from search results.
    ///
    /// This method installs the specified package, tracks installation progress,
    /// and automatically refreshes the package list upon successful completion.
    ///
    /// - Parameters:
    ///   - result: The search result representing the package to install.
    ///   - debugMode: Whether to run in debug mode.
    func installPackage(_ result: SearchResult, debugMode: Bool = false) async {
        logger.info("Installing package \(result.name)")

        installOperations[result.name] = PackageOperation(
            status: .running,
            error: nil,
            diagnostics: "Installing \(result.name)..."
        )

        do {
            try await client.installPackage(result.name, type: result.type, debugMode: debugMode)

            installOperations[result.name] = PackageOperation(
                status: .succeeded,
                error: nil,
                diagnostics: nil
            )
            logHistory(operation: .install, packageName: result.name, success: true)
            // El grafo de dependencias ha cambiado: la caché deja de valer.
            DependenciesStore.invalidateCache()

            // Refresh package list to show newly installed package
            await catalog.refresh(debugMode: debugMode, force: true)

            // Update search results to reflect installation
            if let index = results.firstIndex(where: { $0.id == result.id }) {
                results[index] = SearchResult(
                    name: result.name,
                    type: result.type,
                    isInstalled: true
                )
            }

            // Clear operation after successful refresh
            try? await Task.sleep(for: .seconds(2))
            installOperations.removeValue(forKey: result.name)

        } catch let error as AppError {
            if case .cancelled = error {
                logger.debug("Installation cancelled")
                installOperations[result.name] = .idle
                return
            }

            installOperations[result.name] = PackageOperation(
                status: .failed,
                error: error,
                diagnostics: "Failed to install \(result.name): \(error.localizedDescription)"
            )
            logHistory(operation: .install, packageName: result.name, details: error.localizedDescription, success: false)
        } catch {
            let appError = AppError.brewFailed(exitCode: -1, stderr: error.localizedDescription)
            installOperations[result.name] = PackageOperation(
                status: .failed,
                error: appError,
                diagnostics: "Failed to install \(result.name): \(error.localizedDescription)"
            )
            logHistory(operation: .install, packageName: result.name, details: error.localizedDescription, success: false)
        }
    }

    /// Clears the installation operation status for a package.
    ///
    /// - Parameter packageName: The name of the package to clear the operation for.
    func clearInstallOperation(for packageName: String) {
        installOperations.removeValue(forKey: packageName)
    }

    // MARK: - Private Methods

    /// Emite un error no fatal hacia la raíz, con red de seguridad si el
    /// cableado falta: en debug detiene la ejecución y en release deja traza.
    private func report(_ error: AppError) {
        guard let reportError else {
            logger.fault("reportError sin cablear: se pierde \(error.localizedDescription)")
            assertionFailure("PackageSearchStore usado fuera de PackagesStore")
            return
        }
        reportError(error)
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
