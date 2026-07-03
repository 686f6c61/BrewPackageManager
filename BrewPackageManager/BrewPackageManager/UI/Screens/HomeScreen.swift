//
//  HomeScreen.swift
//  BrewPackageManager
//
//  Pantalla de resumen: estado general, acciones rápidas, actualizaciones
//  pendientes e inventario.
//

import SwiftUI

struct HomeScreen: View {
    @Environment(PackagesStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(NavigationModel.self) private var navigation

    /// Número de filas de inventario visibles (ampliable en bloques de 6).
    @State private var inventoryLimit = 6

    private var attentionPackages: [BrewPackage] {
        Array(store.visibleOutdatedPackages.prefix(6))
    }

    private var trackedPackages: [BrewPackage] {
        Array(store.visiblePackages.prefix(inventoryLimit))
    }

    /// Primera carga: aún no hay inventario que enseñar. Sin esta distinción
    /// la pantalla afirmaría «Everything up to date» antes de saberlo.
    private var isInitialLoad: Bool {
        store.visiblePackages.isEmpty && store.isRefreshing
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                if isInitialLoad {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading packages…")
                            .foregroundStyle(.secondary)
                    }
                    .card()
                } else {
                    summaryCard
                    quickActions
                    updatesSection
                    inventorySection
                }
            }
            .padding(AppTheme.pagePadding)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                title: store.visibleOutdatedCount == 0 ? "Everything up to date" : "\(store.visibleOutdatedCount) updates pending",
                detail: store.visibleOutdatedCount == 0
                    ? "Pinned and hidden updates stay out of the way."
                    : "Update everything visible in one action or review below."
            )
            HStack(spacing: 8) {
                MetricTile(
                    title: "Updates",
                    value: "\(store.visibleOutdatedCount)",
                    tint: store.visibleOutdatedCount == 0 ? AppTheme.statusPositive : AppTheme.statusPending
                )
                MetricTile(title: "Installed", value: "\(store.visiblePackages.count)")
                MetricTile(title: "Hidden", value: "\(store.hiddenItems.count)")
            }
            HStack(spacing: 8) {
                if store.visibleOutdatedCount > 0 {
                    Button("Update all visible", systemImage: "arrow.up.circle") { updateAllVisible() }
                        .buttonStyle(.borderedProminent)
                }
                Button("Refresh", systemImage: "arrow.clockwise") { refresh() }
                    .buttonStyle(.bordered)
                    .disabled(store.isRefreshing)
            }
            .controlSize(.small)
        }
        .card()
    }

    private var quickActions: some View {
        LazyVGrid(columns: AppTheme.twoColumnGrid, spacing: 8) {
            ActionTile(title: "Services", subtitle: "Manage running daemons", systemImage: "gearshape.2", tint: .blue) {
                navigation.navigate(to: .services)
            }
            ActionTile(title: "Cleanup", subtitle: "Cache and old versions", systemImage: "trash", tint: AppTheme.statusPending) {
                navigation.navigate(to: .cleanup)
            }
            if navigation.surface == .popover {
                ActionTile(title: "All tools", subtitle: "Dependencies, history and more", systemImage: "square.grid.2x2", tint: .purple) {
                    navigation.select(tab: .tools)
                }
                ActionTile(title: "Search", subtitle: "Find and install packages", systemImage: "magnifyingglass", tint: AppTheme.statusPositive) {
                    navigation.select(tab: .search)
                }
            }
        }
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                title: "Needs attention",
                detail: attentionPackages.isEmpty
                    ? "Nothing actionable: everything visible is aligned."
                    : "Only user-visible updates appear here."
            )
            ForEach(attentionPackages) { package in
                PackageRow(
                    package: package,
                    actionTitle: "Details",
                    secondaryTitle: "Hide",
                    primaryAction: { showDetails(for: package) },
                    secondaryAction: { store.hideUpdate(for: package) }
                )
            }
        }
    }

    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Installed", detail: "A quick snapshot of the inventory.")
            ForEach(trackedPackages) { package in
                InventoryRow(package: package) { showDetails(for: package) }
            }
            HStack(spacing: 8) {
                if trackedPackages.count < store.visiblePackages.count {
                    Button("Show more") { inventoryLimit = min(inventoryLimit + 6, store.visiblePackages.count) }
                }
                if inventoryLimit > 6 {
                    Button("Show less") { inventoryLimit = 6 }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func refresh() {
        Task { await store.refresh(debugMode: settings.debugMode, force: true) }
    }

    private func updateAllVisible() {
        Task {
            store.selectAllOutdated()
            guard !store.selectedPackageIDs.isEmpty else { return }
            await store.upgradeSelected(debugMode: settings.debugMode)
        }
    }

    private func showDetails(for package: BrewPackage) {
        Task {
            await store.fetchPackageInfo(package.name, type: package.type, debugMode: settings.debugMode)
            if let info = store.selectedPackageInfo {
                navigation.navigate(to: .packageDetail(info))
            }
        }
    }
}
