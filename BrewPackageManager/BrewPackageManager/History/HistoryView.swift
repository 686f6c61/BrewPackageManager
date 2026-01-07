//
//  HistoryView.swift
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

/// View for displaying operation history.
///
/// Shows a chronological list of all operations performed through the app.
struct HistoryView: View {

    // MARK: - Properties

    /// Callback to dismiss the view and return to main menu.
    let onDismiss: () -> Void

    // MARK: - State

    /// History store for managing history data.
    @State private var historyStore = HistoryStore()

    /// Whether to show clear confirmation dialog.
    @State private var showClearConfirmation = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            PanelHeaderView(title: "History", onBack: onDismiss)

            Divider()

            if historyStore.isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading history...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if historyStore.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No History")
                        .font(.headline)
                    Text("Operation history will appear here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    // Filter section
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(
                                title: "All",
                                count: historyStore.entries.count,
                                isSelected: historyStore.selectedFilter == nil
                            ) {
                                historyStore.selectedFilter = nil
                            }

                            ForEach(HistoryEntry.OperationType.allCases, id: \.self) { type in
                                let count = historyStore.operationCounts[type] ?? 0
                                if count > 0 {
                                    FilterChip(
                                        title: type.displayName,
                                        count: count,
                                        isSelected: historyStore.selectedFilter == type
                                    ) {
                                        historyStore.selectedFilter = type
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 8)

                    Divider()

                    // History list
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(historyStore.filteredEntries) { entry in
                                HistoryRow(entry: entry)

                                if entry.id != historyStore.filteredEntries.last?.id {
                                    Divider()
                                        .padding(.leading, 12)
                                }
                            }
                        }
                    }

                    Divider()

                    // Clear history button
                    Button {
                        showClearConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear History")
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
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
        .alert("Clear History", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                Task { await historyStore.clearHistory() }
            }
        } message: {
            Text("This will permanently delete all operation history. This action cannot be undone.")
        }
    }
}

// MARK: - FilterChip

/// Chip for filtering history by operation type.
struct FilterChip: View {

    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                Text("(\(count))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            .foregroundStyle(isSelected ? .white : .primary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - HistoryRow

/// Row displaying a single history entry.
struct HistoryRow: View {

    let entry: HistoryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: entry.operation.icon)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.operation.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    if !entry.success {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }

                Text(entry.packageName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let details = entry.details {
                    Text(details)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(entry.relativeTimestamp)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var iconColor: Color {
        switch entry.operation.color {
        case "green": return .green
        case "blue": return .blue
        case "red": return .red
        case "orange": return .orange
        default: return .secondary
        }
    }
}
