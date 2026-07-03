//
//  MainWindowView.swift
//  BrewPackageManager
//
//  Contenedor del modo ventana: barra lateral translúcida con secciones
//  agrupadas (patrón Finder/Ajustes del Sistema) y detalle con pila propia.
//

import SwiftUI

struct MainWindowView: View {
    @Environment(PackagesStore.self) private var store

    /// Entradas de la barra lateral, agrupadas por secciones.
    enum SidebarItem: String, CaseIterable, Identifiable {
        case overview, search, history
        case services, cleanup, dependencies
        case statistics, settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .overview: return "Overview"
            case .search: return "Search"
            case .history: return "Activity"
            case .services: return "Services"
            case .cleanup: return "Cleanup"
            case .dependencies: return "Dependencies"
            case .statistics: return "Statistics"
            case .settings: return "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .overview: return "square.stack"
            case .search: return "magnifyingglass"
            case .history: return "clock.arrow.circlepath"
            case .services: return "gearshape.2"
            case .cleanup: return "trash"
            case .dependencies: return "point.3.connected.trianglepath.dotted"
            case .statistics: return "chart.bar.xaxis"
            case .settings: return "gearshape"
            }
        }
    }

    @State private var navigation = NavigationModel(surface: .window)
    @State private var selection: SidebarItem? = .overview

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Packages") {
                    sidebarRow(.overview)
                    sidebarRow(.search)
                    sidebarRow(.history)
                }
                Section("Maintenance") {
                    sidebarRow(.services)
                    sidebarRow(.cleanup)
                    sidebarRow(.dependencies)
                }
                Section("System") {
                    sidebarRow(.statistics)
                    sidebarRow(.settings)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            VStack(spacing: 0) {
                // El banner vive en el contenedor, no en cada pantalla: los
                // errores del store compartido deben verse en cualquier sección.
                if let error = store.nonFatalError {
                    ErrorBanner(message: error.localizedDescription, dismiss: { store.dismissError() })
                        .padding(.horizontal, AppTheme.pagePadding)
                        .padding(.top, 8)
                }
                NavigationStack(path: Bindable(navigation).path) {
                    rootScreen(for: selection ?? .overview)
                        .navigationDestination(for: NavigationModel.Destination.self) { destination in
                            DestinationScreen(destination: destination)
                        }
                }
            }
        }
        .frame(minWidth: AppTheme.windowMinWidth, minHeight: AppTheme.windowMinHeight)
        .environment(navigation)
        .onChange(of: selection) {
            // Cambiar de sección descarta la navegación apilada del detalle.
            navigation.popToRoot()
        }
        .onChange(of: navigation.selectedTab) { _, newTab in
            // Las pantallas compartidas cambian de pestaña pensando en el
            // popover; en la ventana se traduce a la sección equivalente.
            switch newTab {
            case .overview: selection = .overview
            case .search: selection = .search
            case .settings: selection = .settings
            case .tools: break // La ventana no tiene pestaña de herramientas.
            }
        }
    }

    private func sidebarRow(_ item: SidebarItem) -> some View {
        Label(item.title, systemImage: item.systemImage)
            .tag(item)
    }

    @ViewBuilder
    private func rootScreen(for item: SidebarItem) -> some View {
        switch item {
        case .overview: HomeScreen()
        case .search: SearchScreen()
        case .history: HistoryScreen()
        case .services: ServicesScreen()
        case .cleanup: CleanupScreen()
        case .dependencies: DependenciesScreen()
        case .statistics: StatisticsScreen()
        case .settings: SettingsScreen()
        }
    }
}
