//
//  CleanupScreen.swift
//  BrewPackageManager
//
//  Limpieza de caché y versiones antiguas, con confirmación previa para la
//  acción destructiva.
//

import SwiftUI

struct CleanupScreen: View {
    @State private var store = CleanupStore()
    @State private var loadTask: Task<Void, Never>?
    @State private var showCleanupConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                if let error = store.lastError {
                    ErrorBanner(message: error.localizedDescription, dismiss: { store.lastError = nil }) {
                        reload()
                    }
                }
                SectionHeader(title: "Cleanup", detail: "Cache and removable versions are separated: one action never pretends to do the other.")
                if store.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Analyzing cache and old versions…")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    MetricTile(title: "Cache", value: store.cleanupInfo.cacheSizeFormatted)
                    MetricTile(title: "Old versions", value: "\(store.cleanupInfo.oldVersions)", tint: AppTheme.statusPending)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Button("Clear download cache", systemImage: "xmark.bin") {
                        Task { await store.clearCache() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isCleaning || store.cleanupInfo.cacheSize == 0)

                    Button("Clean old versions", systemImage: "trash") {
                        showCleanupConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isCleaning || store.cleanupInfo.oldVersions == 0)

                    Button(store.isLoading ? "Refreshing…" : "Refresh analysis", systemImage: "arrow.clockwise") {
                        reload()
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isLoading)
                }
                .controlSize(.small)
                .card()

                VStack(alignment: .leading, spacing: 6) {
                    Text(store.cleanupInfo.cacheExplanation)
                    Text(store.cleanupInfo.oldVersionsExplanation)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let result = store.lastCleanupResult {
                    Text(result)
                        .font(.caption)
                        .card()
                }
            }
            .padding(AppTheme.pagePadding)
        }
        .navigationTitle("Cleanup")
        .task {
            guard !store.isLoading else { return }
            reload()
        }
        .onDisappear {
            loadTask?.cancel()
        }
        .confirmationDialog(
            "Clean old versions?",
            isPresented: $showCleanupConfirmation
        ) {
            Button("Clean", role: .destructive) {
                Task { await store.performCleanup() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes only previous package versions left behind after upgrades. It does not uninstall the current version.")
        }
    }

    private func reload() {
        loadTask?.cancel()
        loadTask = Task { await store.fetchCleanupInfo() }
    }
}
