//
//  MenuPopoverView.swift
//  BrewPackageManager
//
//  Contenedor del popover de la barra de menús: cabecera con estado,
//  control segmentado de pestañas y pila de navegación nativa.
//  Sin fondo propio: el material translúcido lo aporta NSPopover.
//

import SwiftUI

struct MenuPopoverView: View {
    @Environment(PackagesStore.self) private var store
    @Environment(AppSettings.self) private var settings

    @State private var navigation = NavigationModel(surface: .popover)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            // El banner vive en el contenedor, no en cada pantalla: los errores
            // del store compartido deben verse sea cual sea la pestaña activa.
            if let error = store.nonFatalError {
                ErrorBanner(message: error.localizedDescription, dismiss: { store.dismissError() })
                    .padding(.horizontal, AppTheme.pagePadding)
                    .padding(.top, 8)
            }
            NavigationStack(path: Bindable(navigation).path) {
                rootScreen
                    .navigationDestination(for: NavigationModel.Destination.self) { destination in
                        DestinationScreen(destination: destination)
                    }
            }
        }
        .frame(width: AppTheme.popoverWidth, height: AppTheme.popoverHeight)
        .environment(navigation)
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Brew Package Manager")
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(
                    text: store.visibility.visibleOutdatedCount == 0 ? "Up to date" : "\(store.visibility.visibleOutdatedCount) pending",
                    tint: store.visibility.visibleOutdatedCount == 0 ? AppTheme.statusPositive : AppTheme.statusPending
                )
                Button {
                    Task { await store.catalog.refresh(debugMode: settings.debugMode, force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.catalog.isRefreshing)
                .help("Refresh packages")
                .accessibilityLabel("Refresh packages")
            }
            Picker("Section", selection: tabBinding) {
                ForEach(NavigationModel.Tab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(AppTheme.pagePadding)
    }

    @ViewBuilder
    private var rootScreen: some View {
        switch navigation.selectedTab {
        case .overview: HomeScreen()
        case .search: SearchScreen()
        case .tools: ToolsScreen()
        case .settings: SettingsScreen()
        }
    }

    private var subtitle: String {
        if store.visibility.visibleOutdatedCount == 0 {
            return "\(store.visibility.visiblePackages.count) packages · all calm"
        }
        let word = store.visibility.visibleOutdatedCount == 1 ? "package needs" : "packages need"
        return "\(store.visibility.visibleOutdatedCount) \(word) attention"
    }

    /// Binding manual: seleccionar pestaña también limpia la pila.
    private var tabBinding: Binding<NavigationModel.Tab> {
        Binding(
            get: { navigation.selectedTab },
            set: { navigation.select(tab: $0) }
        )
    }
}
