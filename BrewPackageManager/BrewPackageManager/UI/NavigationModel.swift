//
//  NavigationModel.swift
//  BrewPackageManager
//
//  Modelo de navegación de la interfaz nativa. Las pantallas piden navegar
//  a un destino en lugar de recibir closures en cascada desde la raíz,
//  que es lo que hacía crecer sin límite la vista única anterior.
//

import Foundation
import Observation

/// Estado de navegación de una superficie (popover o ventana).
/// Cada contenedor crea su propia instancia: la pestaña activa del popover
/// no debe arrastrar la selección de la ventana ni viceversa.
@MainActor
@Observable
final class NavigationModel {

    /// Superficie que aloja la navegación. Algunas piezas (como la
    /// pestaña Tools) solo tienen sentido en el popover.
    enum Surface {
        case popover
        case window
    }

    /// Pestañas raíz del popover (control segmentado).
    enum Tab: String, CaseIterable, Identifiable {
        case overview, search, tools, settings

        var id: String { rawValue }

        /// Título visible (la interfaz permanece en inglés).
        var title: String {
            switch self {
            case .overview: return "Overview"
            case .search: return "Search"
            case .tools: return "Tools"
            case .settings: return "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .overview: return "square.stack"
            case .search: return "magnifyingglass"
            case .tools: return "square.grid.2x2"
            case .settings: return "gearshape"
            }
        }
    }

    /// Destinos apilables por encima de la pestaña o sección activa.
    enum Destination: Hashable {
        case services
        case cleanup
        case dependencies
        case history
        case statistics
        case hiddenItems
        case help
        case packageDetail(BrewPackageInfo)

        /// Clave estable para igualdad y hashing: `BrewPackageInfo` no es
        /// Hashable, así que el detalle de paquete se identifica por nombre.
        private var key: String {
            switch self {
            case .services: return "services"
            case .cleanup: return "cleanup"
            case .dependencies: return "dependencies"
            case .history: return "history"
            case .statistics: return "statistics"
            case .hiddenItems: return "hidden-items"
            case .help: return "help"
            case .packageDetail(let info): return "package-\(info.fullName)"
            }
        }

        static func == (lhs: Destination, rhs: Destination) -> Bool {
            lhs.key == rhs.key
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }
    }

    let surface: Surface

    /// Pestaña raíz activa (solo relevante en el popover).
    private(set) var selectedTab: Tab = .overview

    /// Pila de destinos por encima de la raíz. Es el `path` que consume
    /// `NavigationStack` en los contenedores.
    var path: [Destination] = []

    init(surface: Surface = .popover) {
        self.surface = surface
    }

    /// Cambia la pestaña raíz y descarta cualquier navegación apilada.
    func select(tab: Tab) {
        selectedTab = tab
        path.removeAll()
    }

    /// Apila un destino sobre la pantalla actual.
    func navigate(to destination: Destination) {
        path.append(destination)
    }

    /// Vuelve a la pantalla anterior; en la raíz no hace nada.
    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Vuelve a la raíz de la pestaña o sección activa.
    func popToRoot() {
        path.removeAll()
    }
}
