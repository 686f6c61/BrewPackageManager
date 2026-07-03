//
//  HistoryScreen.swift
//  BrewPackageManager
//
//  Cronología de operaciones: qué se hizo, cuándo y con qué resultado.
//

import SwiftUI

struct HistoryScreen: View {
    @State private var store = HistoryStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                if let message = store.loadErrorMessage {
                    ErrorBanner(message: message, dismiss: { store.loadErrorMessage = nil }) {
                        Task { await store.loadHistory() }
                    }
                }
                SectionHeader(title: "Activity", detail: "A readable narrative of recent operations.")
                HStack(spacing: 8) {
                    MetricTile(title: "Events", value: "\(store.totalOperations)")
                    MetricTile(title: "Success rate", value: String(format: "%.0f%%", store.successRate), tint: AppTheme.statusPositive)
                }
                ForEach(Array(store.filteredEntries.prefix(20))) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.packageName)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            // El resultado se comunica también con texto, no
                            // solo con el color del distintivo.
                            StatusBadge(
                                text: entry.success
                                    ? entry.operation.rawValue.capitalized
                                    : "\(entry.operation.rawValue.capitalized) failed",
                                tint: entry.success ? AppTheme.statusPositive : AppTheme.statusCritical
                            )
                        }
                        Text(entry.timestamp.formatted(date: .numeric, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let details = entry.details, !details.isEmpty {
                            Text(details)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .card()
                }
            }
            .padding(AppTheme.pagePadding)
        }
        .navigationTitle("Activity")
        .task {
            guard store.entries.isEmpty, !store.isLoading else { return }
            await store.loadHistory()
        }
    }
}
