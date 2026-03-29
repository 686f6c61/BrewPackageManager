//
//  BrewService.swift
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

/// Represents a Homebrew service.
///
/// Services are background processes managed by Homebrew, typically
/// databases, web servers, or other daemons that run continuously.
struct BrewService: Identifiable, Sendable, Hashable, Codable {

    /// Unique identifier for the service (formula name).
    let id: String

    /// The formula name (e.g., "postgresql", "nginx").
    let name: String

    /// Current status of the service.
    let status: ServiceStatus

    /// User running the service (user domain or root domain).
    let user: String?

    /// Process ID if the service is running.
    let pid: Int?

    /// Path to the service's plist file.
    let plist: String?

    /// Exit code reported by Homebrew for failed services.
    let exitCode: Int?

    /// Status of a Homebrew service.
    enum ServiceStatus: String, Sendable, Hashable {
        case started
        case stopped
        case error
        case unknown

        /// Display color for the status.
        var displayColor: String {
            switch self {
            case .started: return "green"
            case .stopped: return "gray"
            case .error: return "red"
            case .unknown: return "orange"
            }
        }

        /// Display text for the status.
        var displayText: String {
            switch self {
            case .started: return "Running"
            case .stopped: return "Stopped"
            case .error: return "Error"
            case .unknown: return "Unknown"
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case status
        case user
        case pid
        case plist
        case file
        case exitCode = "exit_code"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let name = try container.decode(String.self, forKey: .name)
        let rawStatus = try container.decodeIfPresent(String.self, forKey: .status) ?? "unknown"

        self.id = name
        self.name = name
        self.status = Self.mapStatus(rawStatus)
        self.user = try container.decodeIfPresent(String.self, forKey: .user)
        self.pid = try container.decodeIfPresent(Int.self, forKey: .pid)
        self.plist = try container.decodeIfPresent(String.self, forKey: .file)
            ?? container.decodeIfPresent(String.self, forKey: .plist)
        self.exitCode = try container.decodeIfPresent(Int.self, forKey: .exitCode)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(status.rawValue, forKey: .status)
        try container.encodeIfPresent(user, forKey: .user)
        try container.encodeIfPresent(pid, forKey: .pid)
        try container.encodeIfPresent(plist, forKey: .file)
        try container.encodeIfPresent(exitCode, forKey: .exitCode)
    }

    /// Human-friendly context string used by the row details.
    var metadataSummary: String {
        var parts: [String] = [status.displayText]

        if let user, !user.isEmpty {
            parts.append(user)
        }

        if let pid {
            parts.append("PID \(pid)")
        }

        if let exitCode, status == .error {
            parts.append("Exit \(exitCode)")
        }

        return parts.joined(separator: " • ")
    }

    /// Last path component of the plist for compact display.
    var plistDisplayName: String? {
        guard let plist, !plist.isEmpty else { return nil }
        return URL(filePath: plist).lastPathComponent
    }

    private static func mapStatus(_ statusString: String) -> ServiceStatus {
        switch statusString.lowercased() {
        case "started":
            return .started
        case "stopped", "none":
            return .stopped
        case "error":
            return .error
        default:
            return .unknown
        }
    }
}
