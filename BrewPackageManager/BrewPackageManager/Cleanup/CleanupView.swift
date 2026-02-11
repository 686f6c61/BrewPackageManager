//
//  CleanupView.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//  Version: 1.7.0
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// View for managing Homebrew cleanup and cache.
///
/// Displays cache size, old versions count, and provides
/// controls to perform cleanup operations.
struct CleanupView: View {

    // MARK: - Properties

    /// Callback to dismiss the view and return to main menu.
    let onDismiss: () -> Void

    // MARK: - State

    /// Cleanup store for managing cleanup operations.
    @State private var cleanupStore = CleanupStore()

    /// Whether to show cleanup confirmation dialog.
    @State private var showCleanupConfirmation = false

    /// Whether to show cache clear confirmation dialog.
    @State private var showClearCacheConfirmation = false

    /// Active task for initial cleanup info load.
    @State private var loadTask: Task<Void, Never>?

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            PanelHeaderView(title: "Cleanup & Cache", onBack: onDismiss)

            Divider()

            if cleanupStore.isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Analyzing cache...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Cache information
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Cache Size")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(cleanupStore.cleanupInfo.cacheSizeFormatted)
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Old Versions")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(cleanupStore.cleanupInfo.oldVersions)")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                }
                            }

                            if cleanupStore.cleanupInfo.isCleanupRecommended {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                    Text("Cleanup recommended to free up disk space")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding()
                        .sectionContainer()

                        // Statistics
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Details")
                                .font(.headline)

                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text("Cached files:")
                                Spacer()
                                Text("\(cleanupStore.cleanupInfo.cachedFiles)")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)

                            HStack {
                                Image(systemName: "archivebox.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text("Old formula versions:")
                                Spacer()
                                Text("\(cleanupStore.cleanupInfo.oldVersions)")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                        }
                        .padding()
                        .sectionContainer()

                        // Actions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Actions")
                                .font(.headline)

                            Button {
                                showCleanupConfirmation = true
                            } label: {
                                HStack {
                                    if cleanupStore.isCleaning {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "trash")
                                    }
                                    Text("Clean Old Versions")
                                    Spacer()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(cleanupStore.isCleaning || cleanupStore.cleanupInfo.oldVersions == 0)

                            Button {
                                showClearCacheConfirmation = true
                            } label: {
                                HStack {
                                    if cleanupStore.isCleaning {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "xmark.bin")
                                    }
                                    Text("Clear Download Cache")
                                    Spacer()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(cleanupStore.isCleaning || cleanupStore.cleanupInfo.cacheSize == 0)

                            Text("Removes cached downloads and frees disk space")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .sectionContainer()

                        // Last result
                        if let result = cleanupStore.lastCleanupResult {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Success")
                                        .font(.headline)
                                }
                                Text(result)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .sectionContainer()
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 440)
            }
        }
        .frame(width: LayoutConstants.mainMenuWidth)
        .onAppear {
            // Only fetch if not already loading
            if !cleanupStore.isLoading {
                loadTask?.cancel()
                loadTask = Task {
                    await cleanupStore.fetchCleanupInfo()
                }
            }
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
        .alert("Error", isPresented: .init(
            get: { cleanupStore.lastError != nil },
            set: { if !$0 { cleanupStore.lastError = nil } }
        )) {
            Button("OK") { cleanupStore.lastError = nil }
        } message: {
            if let error = cleanupStore.lastError {
                Text(error.localizedDescription)
            }
        }
        .alert("Clean Old Versions", isPresented: $showCleanupConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                Task { await cleanupStore.performCleanup(pruneAll: false) }
            }
        } message: {
            Text("This will remove \(cleanupStore.cleanupInfo.oldVersions) old formula versions. This operation cannot be undone.")
        }
        .alert("Clear Download Cache", isPresented: $showClearCacheConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                Task { await cleanupStore.clearCache() }
            }
        } message: {
            Text("This will remove all cached downloads (\(cleanupStore.cleanupInfo.cacheSizeFormatted)). Packages will be re-downloaded when needed.")
        }
    }
}
