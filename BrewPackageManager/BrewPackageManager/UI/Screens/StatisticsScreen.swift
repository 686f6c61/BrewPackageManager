//
//  StatisticsScreen.swift
//  BrewPackageManager
//
//  Resumen de uso: totales y desglose por tipo de operación.
//

import SwiftUI

struct StatisticsScreen: View {
    @State private var store = HistoryStore()

    /// Operaciones ordenadas alfabéticamente para un desglose estable.
    private var sortedOperations: [HistoryEntry.OperationType] {
        store.operationCounts.keys.sorted(by: { $0.rawValue < $1.rawValue })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                if let message = store.loadErrorMessage {
                    ErrorBanner(message: message, dismiss: { store.loadErrorMessage = nil }) {
                        Task { await store.loadHistory() }
                    }
                }
                SectionHeader(title: "Statistics", detail: "Fast understanding of usage trends.")
                if store.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading statistics…")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    MetricTile(title: "Operations", value: "\(store.totalOperations)")
                    MetricTile(title: "Success", value: String(format: "%.0f%%", store.successRate), tint: AppTheme.statusPositive)
                }
                VStack(spacing: 0) {
                    ForEach(sortedOperations, id: \.rawValue) { operation in
                        HStack {
                            Text(operation.rawValue.capitalized)
                                .font(.subheadline)
                            Spacer()
                            Text("\(store.operationCounts[operation, default: 0])")
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.vertical, 8)
                        if operation != sortedOperations.last {
                            Divider()
                        }
                    }
                }
                .card()
            }
            .padding(AppTheme.pagePadding)
        }
        .navigationTitle("Statistics")
        .task {
            guard store.entries.isEmpty, !store.isLoading else { return }
            await store.loadHistory()
        }
    }
}
