//
//  DependenciesScreen.swift
//  BrewPackageManager
//
//  Mapa de dependencias: qué depende de qué antes de desinstalar.
//

import SwiftUI

struct DependenciesScreen: View {
    @State private var store = DependenciesStore()
    @State private var filter = ""

    private var filtered: [DependencyInfo] {
        let trimmed = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return store.dependencies }
        return store.dependencies.filter { $0.packageName.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                if let error = store.lastError {
                    ErrorBanner(message: error.localizedDescription, dismiss: { store.lastError = nil }) {
                        Task { await store.fetchAllDependencies() }
                    }
                }
                SectionHeader(title: "Dependencies", detail: "Consequences before you uninstall or refactor your setup.")
                HStack(spacing: 8) {
                    MetricTile(title: "Packages", value: "\(store.dependencies.count)")
                    MetricTile(title: "Total deps", value: "\(store.totalDependencies)", tint: .purple)
                }
                TextField("Filter packages", text: $filter)
                    .textFieldStyle(.roundedBorder)

                if store.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Mapping dependencies…")
                            .foregroundStyle(.secondary)
                    }
                } else if filtered.isEmpty {
                    ContentUnavailableView(
                        filter.isEmpty ? "No dependencies yet" : "No matches",
                        systemImage: "point.3.connected.trianglepath.dotted",
                        description: Text(filter.isEmpty
                            ? "Dependency data appears here after the first analysis."
                            : "No package matches the current filter.")
                    )
                } else {
                    // LazyVStack: la lista puede contener todo el inventario
                    // instalado y no debe medirse entera de golpe.
                    LazyVStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                        ForEach(filtered) { dependency in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(dependency.packageName)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    StatusBadge(text: "\(dependency.dependencies.count) deps", tint: .purple)
                                }
                                Text(dependency.dependencies.isEmpty ? "No dependencies" : dependency.dependencies.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .card()
                        }
                    }
                }
            }
            .padding(AppTheme.pagePadding)
        }
        .navigationTitle("Dependencies")
        .task {
            guard store.dependencies.isEmpty, !store.isLoading else { return }
            await store.fetchAllDependencies()
        }
    }
}
