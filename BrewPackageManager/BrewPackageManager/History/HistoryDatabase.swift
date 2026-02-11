//
//  HistoryDatabase.swift
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

/// Actor responsible for persisting and retrieving history entries.
///
/// Uses UserDefaults with JSON serialization for simple persistence.
/// Entries are stored in memory and periodically flushed to disk.
@preconcurrency
actor HistoryDatabase {

    // MARK: - Properties

    /// Logger for database operations.
    private let logger = Logger(subsystem: "BrewPackageManager", category: "HistoryDatabase")

    /// UserDefaults key for storing history entries.
    private let historyKey = "brewPackageManager.history"

    /// Maximum number of entries to keep in history.
    private let maxEntries = 1000

    /// UserDefaults instance for persistence.
    private let defaults = UserDefaults.standard

    // MARK: - Public Methods

    /// Add a new history entry.
    ///
    /// - Parameter entry: The entry to add.
    func addEntry(_ entry: HistoryEntry) async {
        logger.info("Adding history entry: \(entry.operation.rawValue) - \(entry.packageName)")

        var entries = await loadEntries()
        entries.insert(entry, at: 0) // Insert at beginning for chronological order

        // Trim to max entries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        await saveEntries(entries)
    }

    /// Load all history entries.
    ///
    /// - Returns: Array of history entries, sorted by timestamp (newest first).
    func loadEntries() async -> [HistoryEntry] {
        guard let data = defaults.data(forKey: historyKey) else {
            logger.info("No history entries found")
            return []
        }

        do {
            let decoded = try JSONDecoder().decode([HistoryEntryDTO].self, from: data)
            let entries = decoded.map { $0.toEntry() }
            logger.info("Loaded \(entries.count) history entries")
            return entries
        } catch {
            logger.error("Failed to decode history entries: \(error.localizedDescription)")
            return []
        }
    }

    /// Clear all history entries.
    func clearHistory() async {
        logger.info("Clearing all history entries")
        defaults.removeObject(forKey: historyKey)
    }

    /// Get entries filtered by operation type.
    ///
    /// - Parameter operation: The operation type to filter by.
    /// - Returns: Filtered array of entries.
    func getEntries(for operation: HistoryEntry.OperationType) async -> [HistoryEntry] {
        let allEntries = await loadEntries()
        return allEntries.filter { $0.operation == operation }
    }

    /// Get entries for a specific package.
    ///
    /// - Parameter packageName: The package name.
    /// - Returns: Array of entries for the package.
    func getEntries(for packageName: String) async -> [HistoryEntry] {
        let allEntries = await loadEntries()
        return allEntries.filter { $0.packageName == packageName }
    }

    // MARK: - Private Methods

    /// Save entries to UserDefaults.
    private func saveEntries(_ entries: [HistoryEntry]) async {
        let dtos = entries.map { HistoryEntryDTO(from: $0) }

        do {
            let encoded = try JSONEncoder().encode(dtos)
            defaults.set(encoded, forKey: historyKey)
            logger.info("Saved \(entries.count) history entries")
        } catch {
            logger.error("Failed to encode history entries: \(error.localizedDescription)")
        }
    }
}

// MARK: - HistoryEntryDTO

/// Data Transfer Object for encoding/decoding HistoryEntry.
private struct HistoryEntryDTO: Codable, Sendable {

    let id: String
    let timestamp: TimeInterval
    let operation: String
    let packageName: String
    let details: String?
    let success: Bool

    nonisolated init(from entry: HistoryEntry) {
        self.id = entry.id.uuidString
        self.timestamp = entry.timestamp.timeIntervalSince1970
        self.operation = entry.operation.rawValue
        self.packageName = entry.packageName
        self.details = entry.details
        self.success = entry.success
    }

    nonisolated func toEntry() -> HistoryEntry {
        HistoryEntry(
            id: UUID(uuidString: id) ?? UUID(),
            timestamp: Date(timeIntervalSince1970: timestamp),
            operation: HistoryEntry.OperationType(rawValue: operation) ?? .refresh,
            packageName: packageName,
            details: details,
            success: success
        )
    }
}
