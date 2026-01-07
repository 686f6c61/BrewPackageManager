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
struct BrewService: Identifiable, Sendable, Hashable {

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
}

extension BrewService {

    /// Parse a service from brew services list JSON output.
    nonisolated static func parse(from json: [String: Any]) -> BrewService? {
        guard let name = json["name"] as? String else { return nil }

        let statusString = json["status"] as? String ?? "unknown"

        // Map brew services status to our enum
        let status: ServiceStatus = {
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
        }()

        // Try both "file" (new format) and "plist" (old format)
        let plistPath = json["file"] as? String ?? json["plist"] as? String

        return BrewService(
            id: name,
            name: name,
            status: status,
            user: json["user"] as? String,
            pid: json["pid"] as? Int,
            plist: plistPath
        )
    }
}
