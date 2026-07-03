//
//  SearchScreen.swift
//  BrewPackageManager
//
//  Búsqueda en vivo de fórmulas y casks con filtro por tipo e instalación
//  directa desde el resultado.
//

import SwiftUI

struct SearchScreen: View {
    @Environment(PackagesStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(NavigationModel.self) private var navigation

    @State private var searchText = ""
    /// Tarea de búsqueda con debounce; se cancela al teclear o salir.
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                controls
                results
            }
            .padding(AppTheme.pagePadding)
        }
        .onDisappear {
            searchTask?.cancel()
            searchTask = nil
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search formulae or casks", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, newValue in
                    scheduleSearch(for: newValue)
                }
            Picker("Type", selection: typeFilterBinding) {
                Text("All").tag(PackageType?.none)
                Text("Formulae").tag(PackageType?.some(.formula))
                Text("Casks").tag(PackageType?.some(.cask))
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private var results: some View {
        switch store.search.state {
        case .idle:
            ContentUnavailableView(
                "Search Homebrew",
                systemImage: "magnifyingglass",
                description: Text("Results show install state, type and direct access to details.")
            )
        case .searching(let query):
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Searching for \(query)…")
                    .foregroundStyle(.secondary)
            }
            .card()
        case .loaded(_, let results, let hasMore):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(results) { result in
                    SearchResultRow(result: result, operation: store.search.installOperations[result.name]) {
                        Task { await store.search.installPackage(result, debugMode: settings.debugMode) }
                    } detailsAction: {
                        showDetails(for: result)
                    }
                }
                if hasMore {
                    Text("Refine the query to narrow down more results.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .error(let error):
            ContentUnavailableView(
                "Search failed",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription)
            )
        }
    }

    /// Binding manual porque el filtro vive en el store compartido.
    private var typeFilterBinding: Binding<PackageType?> {
        Binding(
            get: { store.search.typeFilter },
            set: { newValue in
                store.search.typeFilter = newValue
                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    scheduleSearch(for: searchText, immediately: true)
                }
            }
        )
    }

    private func scheduleSearch(for query: String, immediately: Bool = false) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            store.search.clearSearch(resetFilter: false)
            return
        }
        searchTask = Task {
            if !immediately {
                try? await Task.sleep(for: .milliseconds(350))
            }
            guard !Task.isCancelled else { return }
            await store.search.search(query: trimmed, debugMode: settings.debugMode)
        }
    }

    private func showDetails(for result: SearchResult) {
        Task {
            await store.search.fetchSearchResultInfo(result, debugMode: settings.debugMode)
            if let updated = store.search.results.first(where: { $0.id == result.id }),
               let info = updated.info {
                navigation.navigate(to: .packageDetail(info))
            }
        }
    }
}
