//
//  HistoryStore.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//  Version: 1.7.0
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation
import OSLog
import Observation

/// Store for managing history and statistics.
///
/// This observable store coordinates history tracking and provides
/// statistics about package operations.
@MainActor
@Observable
final class HistoryStore {

    // MARK: - Properties

    /// All history entries.
    var entries: [HistoryEntry] = []

    /// Whether the store is currently loading.
    var isLoading = false

    /// Selected filter for operation type.
    var selectedFilter: HistoryEntry.OperationType?

    /// Logger for history store operations.
    private let logger = Logger(subsystem: "BrewPackageManager", category: "HistoryStore")

    /// History database for persistence.
    private let database = HistoryDatabase()

    /// Shared database used by static logging calls.
    private static let sharedDatabase = HistoryDatabase()

    // MARK: - Computed Properties

    /// Filtered entries based on selected filter.
    var filteredEntries: [HistoryEntry] {
        if let filter = selectedFilter {
            return entries.filter { $0.operation == filter }
        }
        return entries
    }

    /// Statistics: count by operation type.
    var operationCounts: [HistoryEntry.OperationType: Int] {
        var counts: [HistoryEntry.OperationType: Int] = [:]
        for entry in entries {
            counts[entry.operation, default: 0] += 1
        }
        return counts
    }

    /// Statistics: most installed packages.
    var mostInstalledPackages: [(name: String, count: Int)] {
        let installEntries = entries.filter { $0.operation == .install }
        let packageCounts = Dictionary(grouping: installEntries, by: { $0.packageName })
            .mapValues { $0.count }
        return packageCounts.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
    }

    /// Statistics: most upgraded packages.
    var mostUpgradedPackages: [(name: String, count: Int)] {
        let upgradeEntries = entries.filter { $0.operation == .upgrade }
        let packageCounts = Dictionary(grouping: upgradeEntries, by: { $0.packageName })
            .mapValues { $0.count }
        return packageCounts.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
    }

    /// Total operations performed.
    var totalOperations: Int {
        entries.count
    }

    /// Success rate percentage.
    var successRate: Double {
        guard !entries.isEmpty else { return 0 }
        let successCount = entries.filter { $0.success }.count
        return (Double(successCount) / Double(entries.count)) * 100
    }

    // MARK: - Public Methods

    /// Load all history entries from database.
    func loadHistory() async {
        guard !isLoading else { return }

        isLoading = true
        logger.info("Loading history")

        let loadedEntries = await database.loadEntries()
        entries = loadedEntries

        logger.info("Loaded \(loadedEntries.count) history entries")
        isLoading = false
    }

    /// Add a new history entry.
    ///
    /// - Parameter entry: The entry to add.
    func addEntry(_ entry: HistoryEntry) async {
        logger.info("Adding entry: \(entry.operation.rawValue) - \(entry.packageName)")

        await database.addEntry(entry)
        entries.insert(entry, at: 0) // Add to beginning
    }

    /// Clear all history.
    func clearHistory() async {
        logger.info("Clearing all history")

        await database.clearHistory()
        entries = []
    }

    /// Log an operation to history.
    ///
    /// Convenience method to create and add an entry in one call.
    ///
    /// - Parameters:
    ///   - operation: The operation type.
    ///   - packageName: The package name.
    ///   - details: Optional details.
    ///   - success: Whether the operation succeeded.
    static func logOperation(
        operation: HistoryEntry.OperationType,
        packageName: String,
        details: String? = nil,
        success: Bool = true
    ) async {
        let entry = HistoryEntry.create(
            operation: operation,
            packageName: packageName,
            details: details,
            success: success
        )

        await sharedDatabase.addEntry(entry)
    }
}
