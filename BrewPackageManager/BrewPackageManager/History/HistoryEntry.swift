//
//  HistoryEntry.swift
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

/// Represents a history entry for package operations.
///
/// Tracks all operations performed through the app for audit and statistics.
struct HistoryEntry: Identifiable, Sendable, Hashable {

    /// Unique identifier for the entry.
    let id: UUID

    /// Timestamp when the operation occurred.
    let timestamp: Date

    /// Type of operation performed.
    let operation: OperationType

    /// Package name affected by the operation.
    let packageName: String

    /// Optional additional details or notes.
    let details: String?

    /// Whether the operation succeeded.
    let success: Bool

    /// Type of package operation.
    enum OperationType: String, Sendable, CaseIterable {
        case install = "install"
        case upgrade = "upgrade"
        case uninstall = "uninstall"
        case refresh = "refresh"
        case search = "search"
        case cleanup = "cleanup"
        case serviceStart = "service_start"
        case serviceStop = "service_stop"
        case serviceRestart = "service_restart"

        /// Display name for the operation.
        var displayName: String {
            switch self {
            case .install: return "Install"
            case .upgrade: return "Upgrade"
            case .uninstall: return "Uninstall"
            case .refresh: return "Refresh"
            case .search: return "Search"
            case .cleanup: return "Cleanup"
            case .serviceStart: return "Start Service"
            case .serviceStop: return "Stop Service"
            case .serviceRestart: return "Restart Service"
            }
        }

        /// Icon for the operation.
        var icon: String {
            switch self {
            case .install: return "plus.circle"
            case .upgrade: return "arrow.up.circle"
            case .uninstall: return "trash"
            case .refresh: return "arrow.clockwise"
            case .search: return "magnifyingglass"
            case .cleanup: return "trash.circle"
            case .serviceStart: return "play.circle"
            case .serviceStop: return "stop.circle"
            case .serviceRestart: return "arrow.clockwise.circle"
            }
        }

        /// Color for the operation.
        var color: String {
            switch self {
            case .install: return "green"
            case .upgrade: return "blue"
            case .uninstall: return "red"
            case .refresh: return "blue"
            case .search: return "gray"
            case .cleanup: return "orange"
            case .serviceStart: return "green"
            case .serviceStop: return "red"
            case .serviceRestart: return "orange"
            }
        }
    }
}

extension HistoryEntry {

    /// Create a new history entry with the current timestamp.
    static func create(
        operation: OperationType,
        packageName: String,
        details: String? = nil,
        success: Bool = true
    ) -> HistoryEntry {
        HistoryEntry(
            id: UUID(),
            timestamp: Date(),
            operation: operation,
            packageName: packageName,
            details: details,
            success: success
        )
    }

    /// Format the timestamp as a relative time string.
    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    /// Format the timestamp as an absolute date string.
    var absoluteTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
