//
//  PackageVisibilityStore.swift
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

/// Gestiona qué paquetes y actualizaciones están ocultos para el usuario.
///
/// Persiste los identificadores ocultos en `UserDefaults` y deriva del
/// catálogo las vistas filtradas (`visiblePackages`, `hiddenItems`...). Al
/// ocultar un elemento notifica por `onPackageHidden` para que la selección
/// activa se limpie sin acoplar este store al de operaciones.
@MainActor
@Observable
final class PackageVisibilityStore {

    /// Un paquete o actualización oculto que sigue instalado y puede gestionarse en la UI.
    struct HiddenItem: Identifiable, Equatable {
        enum Kind: String, Equatable {
            case package
            case update

            var title: String {
                switch self {
                case .package:
                    "Hidden Package"
                case .update:
                    "Hidden Update"
                }
            }
        }

        let package: BrewPackage
        let kind: Kind

        var id: String { "\(kind.rawValue):\(package.id)" }
    }

    /// Keys for package visibility preferences persisted by the store.
    private enum DefaultsKeys {
        static let hiddenPackageIDs = "hiddenPackageIDs"
        static let hiddenUpdatePackageIDs = "hiddenUpdatePackageIDs"
    }

    /// Defaults storage for lightweight UI preferences owned by the store.
    private let defaults: UserDefaults

    /// Catálogo del que se derivan las vistas filtradas.
    private let catalog: PackagesCatalogStore

    /// Invocado con el ID afectado al ocultar un paquete o su actualización,
    /// para que la raíz retire ese paquete de la selección activa.
    @ObservationIgnored var onPackageHidden: ((String) -> Void)?

    /// Package IDs hidden from the main packages list.
    private(set) var hiddenPackageIDs: Set<String> = [] {
        didSet { persistSet(hiddenPackageIDs, forKey: DefaultsKeys.hiddenPackageIDs) }
    }

    /// Package IDs whose update state is hidden while keeping the package visible.
    private(set) var hiddenUpdatePackageIDs: Set<String> = [] {
        didSet { persistSet(hiddenUpdatePackageIDs, forKey: DefaultsKeys.hiddenUpdatePackageIDs) }
    }

    // MARK: - Computed Properties

    /// Packages visible in the main list after applying hidden package rules.
    var visiblePackages: [BrewPackage] {
        catalog.packages.filter { !isPackageHidden($0) }
    }

    /// Packages with user-visible, actionable updates.
    var visibleOutdatedPackages: [BrewPackage] {
        visiblePackages.filter { hasVisibleUpdate($0) }
    }

    /// Number of user-visible, actionable updates.
    var visibleOutdatedCount: Int {
        visibleOutdatedPackages.count
    }

    /// Hidden packages and updates that are still installed and can be managed in the UI.
    var hiddenItems: [HiddenItem] {
        catalog.packages
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            .compactMap { package in
                if hiddenPackageIDs.contains(package.id) {
                    return HiddenItem(package: package, kind: .package)
                }
                if hiddenUpdatePackageIDs.contains(package.id) {
                    return HiddenItem(package: package, kind: .update)
                }
                return nil
            }
    }

    // MARK: - Initialization

    /// Crea el store de visibilidad enlazado a un catálogo.
    ///
    /// - Parameters:
    ///   - catalog: El catálogo del que se derivan las vistas filtradas.
    ///   - defaults: El almacén de preferencias para los IDs ocultos.
    init(catalog: PackagesCatalogStore, defaults: UserDefaults) {
        self.catalog = catalog
        self.defaults = defaults
        hiddenPackageIDs = Self.loadStoredSet(from: defaults, forKey: DefaultsKeys.hiddenPackageIDs)
        hiddenUpdatePackageIDs = Self.loadStoredSet(from: defaults, forKey: DefaultsKeys.hiddenUpdatePackageIDs)
    }

    // MARK: - Queries

    /// Returns whether the package is hidden from the main packages list.
    func isPackageHidden(_ package: BrewPackage) -> Bool {
        hiddenPackageIDs.contains(package.id)
    }

    /// Returns whether the package's update state is hidden.
    func isUpdateHidden(_ package: BrewPackage) -> Bool {
        hiddenUpdatePackageIDs.contains(package.id)
    }

    /// Returns whether a package has a visible, actionable update.
    func hasVisibleUpdate(_ package: BrewPackage) -> Bool {
        guard package.hasUpdate else { return false }
        guard !isPackageHidden(package), !isUpdateHidden(package) else { return false }
        return !catalog.isPackagePinned(package)
    }

    /// Returns whether the package has an update that is blocked because it is pinned.
    func showsPinnedUpdateNotice(_ package: BrewPackage) -> Bool {
        guard package.hasUpdate else { return false }
        guard !isPackageHidden(package), !isUpdateHidden(package) else { return false }
        return catalog.isPackagePinned(package)
    }

    // MARK: - Mutations

    /// Hides the package from the installed packages list.
    func hidePackage(_ package: BrewPackage) {
        hiddenPackageIDs.insert(package.id)
        hiddenUpdatePackageIDs.remove(package.id)
        notifyPackageHidden(package.id)
    }

    /// Restores a previously hidden package.
    func unhidePackage(_ packageID: String) {
        hiddenPackageIDs.remove(packageID)
    }

    /// Hides the update state for a package while keeping the package visible.
    func hideUpdate(for package: BrewPackage) {
        guard package.hasUpdate, !isPackageHidden(package) else { return }
        hiddenUpdatePackageIDs.insert(package.id)
        notifyPackageHidden(package.id)
    }

    /// Notifica un ocultamiento a la raíz, con red de seguridad si el
    /// cableado falta: en debug detiene la ejecución para hacerlo visible.
    private func notifyPackageHidden(_ packageID: String) {
        guard let onPackageHidden else {
            assertionFailure("PackageVisibilityStore usado fuera de PackagesStore: la selección no se limpia")
            return
        }
        onPackageHidden(packageID)
    }

    /// Restores a previously hidden update.
    func unhideUpdate(for packageID: String) {
        hiddenUpdatePackageIDs.remove(packageID)
    }

    /// Elimina de los sets ocultos los paquetes que ya no están instalados.
    func reconcile(with packages: [BrewPackage]) {
        let packageIDs = Set(packages.map(\.id))
        hiddenPackageIDs.formIntersection(packageIDs)
        hiddenUpdatePackageIDs.formIntersection(packageIDs)
    }

    // MARK: - Persistence

    /// Loads a stored set of strings from defaults.
    private static func loadStoredSet(from defaults: UserDefaults, forKey key: String) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    /// Persists a set of strings to defaults using a stable ordering.
    private func persistSet(_ set: Set<String>, forKey key: String) {
        if set.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(set.sorted(), forKey: key)
        }
    }
}
