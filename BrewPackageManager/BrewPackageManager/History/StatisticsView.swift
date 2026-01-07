//
//  StatisticsView.swift
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

/// View for displaying usage statistics.
///
/// Shows aggregated statistics about package operations performed.
struct StatisticsView: View {

    // MARK: - Properties

    /// Callback to dismiss the view and return to main menu.
    let onDismiss: () -> Void

    // MARK: - State

    /// History store for accessing statistics data.
    @State private var historyStore = HistoryStore()

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            PanelHeaderView(title: "Statistics", onBack: onDismiss)

            Divider()

            if historyStore.isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading statistics...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if historyStore.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No Statistics")
                        .font(.headline)
                    Text("Statistics will appear after operations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Overview
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Overview")
                                .font(.headline)

                            HStack(spacing: 16) {
                                StatCard(
                                    title: "Total Operations",
                                    value: "\(historyStore.totalOperations)",
                                    icon: "chart.line.uptrend.xyaxis"
                                )

                                StatCard(
                                    title: "Success Rate",
                                    value: String(format: "%.1f%%", historyStore.successRate),
                                    icon: "checkmark.circle"
                                )
                            }
                        }
                        .padding()
                        .sectionContainer()

                        // Operations breakdown
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Operations")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(HistoryEntry.OperationType.allCases, id: \.self) { type in
                                    let count = historyStore.operationCounts[type] ?? 0
                                    if count > 0 {
                                        OperationBar(
                                            operation: type,
                                            count: count,
                                            total: historyStore.totalOperations
                                        )
                                    }
                                }
                            }
                        }
                        .padding()
                        .sectionContainer()

                        // Most installed packages
                        if !historyStore.mostInstalledPackages.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Most Installed")
                                    .font(.headline)

                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(historyStore.mostInstalledPackages.prefix(5), id: \.name) { item in
                                        HStack {
                                            Text(item.name)
                                                .font(.caption)
                                            Spacer()
                                            Text("\(item.count)x")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .sectionContainer()
                        }

                        // Most upgraded packages
                        if !historyStore.mostUpgradedPackages.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Most Upgraded")
                                    .font(.headline)

                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(historyStore.mostUpgradedPackages.prefix(5), id: \.name) { item in
                                        HStack {
                                            Text(item.name)
                                                .font(.caption)
                                            Spacer()
                                            Text("\(item.count)x")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
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
            // Only load if not already loading
            if !historyStore.isLoading {
                Task {
                    await historyStore.loadHistory()
                }
            }
        }
    }
}

// MARK: - StatCard

/// Card displaying a single statistic.
struct StatCard: View {

    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - OperationBar

/// Bar chart row for operation statistics.
struct OperationBar: View {

    let operation: HistoryEntry.OperationType
    let count: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: operation.icon)
                        .font(.caption2)
                        .foregroundStyle(barColor)
                    Text(operation.displayName)
                        .font(.caption)
                }

                Spacer()

                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 6)

                    Rectangle()
                        .fill(barColor)
                        .frame(width: barWidth(in: geometry.size.width), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private var barColor: Color {
        switch operation.color {
        case "green": return .green
        case "blue": return .blue
        case "red": return .red
        case "orange": return .orange
        default: return .secondary
        }
    }

    private func barWidth(in totalWidth: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        let percentage = CGFloat(count) / CGFloat(total)
        return totalWidth * percentage
    }
}
