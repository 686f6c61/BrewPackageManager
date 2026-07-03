//
//  ServicesScreen.swift
//  BrewPackageManager
//
//  Gestión de servicios de Homebrew (brew services). El store es local a la
//  pantalla, como en la interfaz anterior. Los errores se muestran en un
//  banner contextual en lugar de una alerta modal.
//

import SwiftUI

struct ServicesScreen: View {
    @State private var store = ServicesStore()
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                if let error = store.lastError {
                    ErrorBanner(message: error.localizedDescription, dismiss: { store.lastError = nil }) {
                        reload()
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Services", detail: "Each row only shows the actions valid for its state.")
                    HStack(spacing: 8) {
                        MetricTile(title: "Running", value: "\(store.runningCount)", tint: AppTheme.statusPositive)
                        MetricTile(title: "Stopped", value: "\(store.stoppedCount)", tint: AppTheme.statusPending)
                    }
                    Button(store.isRefreshing ? "Refreshing…" : "Refresh services", systemImage: "arrow.clockwise") {
                        reload()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(store.isRefreshing)
                }
                .card()

                if let statusMessage = store.statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if store.isLoading && store.services.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading services…")
                            .foregroundStyle(.secondary)
                    }
                } else if store.services.isEmpty {
                    ContentUnavailableView(
                        "No services",
                        systemImage: "gearshape.2",
                        description: Text("Packages that provide background services appear here.")
                    )
                }

                ForEach(store.services) { service in
                    ServiceRow(
                        service: service,
                        operationState: store.operationState(for: service.id),
                        onStart: { await store.startService(service) },
                        onStop: { await store.stopService(service) },
                        onRestart: { await store.restartService(service) }
                    )
                }
            }
            .padding(AppTheme.pagePadding)
        }
        .navigationTitle("Services")
        .task {
            guard store.services.isEmpty, !store.isLoading else { return }
            reload()
        }
        .onDisappear {
            loadTask?.cancel()
        }
    }

    private func reload() {
        loadTask?.cancel()
        loadTask = Task { await store.fetchServices(showStatusMessage: true) }
    }
}
