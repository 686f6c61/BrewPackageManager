//
//  DependenciesView.swift
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

/// View for displaying package dependencies.
///
/// Shows all installed packages with their dependencies,
/// and allows drilling down into specific package details.
struct DependenciesView: View {

    // MARK: - Properties

    /// Callback to dismiss the view and return to main menu.
    let onDismiss: () -> Void

    // MARK: - State

    /// Dependencies store for managing dependency data.
    @State private var dependenciesStore = DependenciesStore()

    /// Search filter text.
    @State private var searchText = ""

    /// Show export confirmation.
    @State private var showExportConfirmation = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            // Header with Export button
            HStack {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                Text("Dependencies")
                    .font(.headline)

                Spacer()

                Button {
                    exportToCSV()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export CSV")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(dependenciesStore.dependencies.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if dependenciesStore.isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading dependencies...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if dependenciesStore.dependencies.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No Dependencies Found")
                        .font(.headline)
                    Text("No packages are installed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Summary section
                        HStack(spacing: 16) {
                            SummaryBadge(
                                count: dependenciesStore.dependencies.count,
                                label: "Packages",
                                icon: "cube.box"
                            )
                            SummaryBadge(
                                count: dependenciesStore.totalDependencies,
                                label: "Dependencies",
                                icon: "link"
                            )
                        }
                        .padding()
                        .sectionContainer()

                        // Search field
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Filter packages...", text: $searchText)
                                .textFieldStyle(.plain)
                        }
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                        .padding(.horizontal)

                        // Dependencies list
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredDependencies) { depInfo in
                                DependencyRow(dependency: depInfo)

                                if depInfo.id != filteredDependencies.last?.id {
                                    Divider()
                                        .padding(.leading, 12)
                                }
                            }
                        }
                        .sectionContainer()
                    }
                    .padding()
                }
                .frame(maxHeight: 440)
            }
        }
        .frame(width: LayoutConstants.mainMenuWidth)
        .onAppear {
            // Only fetch if we don't have data and aren't already loading
            if dependenciesStore.dependencies.isEmpty && !dependenciesStore.isLoading {
                Task {
                    await dependenciesStore.fetchAllDependencies()
                }
            }
        }
        .alert("Error", isPresented: .init(
            get: { dependenciesStore.lastError != nil },
            set: { if !$0 { dependenciesStore.lastError = nil } }
        )) {
            Button("OK") { dependenciesStore.lastError = nil }
        } message: {
            if let error = dependenciesStore.lastError {
                Text(error.localizedDescription)
            }
        }
        .alert("CSV Exported", isPresented: $showExportConfirmation) {
            Button("OK") { showExportConfirmation = false }
        } message: {
            Text("Dependencies exported to Downloads folder")
        }
    }

    // MARK: - Computed Properties

    private var filteredDependencies: [DependencyInfo] {
        if searchText.isEmpty {
            return dependenciesStore.dependencies
        } else {
            return dependenciesStore.dependencies.filter {
                $0.packageName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Methods

    /// Export dependencies to CSV file.
    private func exportToCSV() {
        var csv = "Package,Dependencies Count,Dependencies,Optional Dependencies,Build Dependencies,Used By\n"

        for dep in dependenciesStore.dependencies {
            let deps = dep.dependencies.joined(separator: "; ")
            let optionalDeps = dep.optionalDependencies.joined(separator: "; ")
            let buildDeps = dep.buildDependencies.joined(separator: "; ")
            let usedBy = dep.isUsedBy.joined(separator: "; ")

            csv += "\"\(dep.packageName)\",\(dep.dependencyCount),\"\(deps)\",\"\(optionalDeps)\",\"\(buildDeps)\",\"\(usedBy)\"\n"
        }

        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let fileURL = downloadsURL.appendingPathComponent("brew-dependencies-\(timestamp).csv")

        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            showExportConfirmation = true
        } catch {
            dependenciesStore.lastError = AppError.unknown("Failed to export CSV: \(error.localizedDescription)")
        }
    }
}

// MARK: - SummaryBadge

/// Badge displaying a summary statistic.
struct SummaryBadge: View {

    let count: Int
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .font(.caption)
            Text("\(count)")
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - DependencyRow

/// Row displaying a single package with its dependency count.
struct DependencyRow: View {

    let dependency: DependencyInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dependency.packageName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack(spacing: 8) {
                        if dependency.hasDependencies {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                Text("\(dependency.dependencyCount) deps")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text("No dependencies")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if dependency.isRequired {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Text("Used by \(dependency.isUsedBy.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Spacer()
            }

            // Show dependencies list if available
            if dependency.hasDependencies {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(dependency.dependencies.prefix(5), id: \.self) { dep in
                        HStack(spacing: 4) {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(dep)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if dependency.dependencies.count > 5 {
                        Text("+ \(dependency.dependencies.count - 5) more...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 8)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
