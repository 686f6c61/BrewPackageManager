//
//  BrewResponseTypes.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

// MARK: - Brew Info Response

/// Response structure for `brew info --json=v2` commands.
///
/// This structure maps the JSON output from Homebrew's info command, which
/// contains arrays of formulae (command-line tools) and casks (GUI applications).
nonisolated struct BrewInfoResponse: Codable, Sendable {

    /// Decodes a BrewInfoResponse from a JSON string.
    ///
    /// - Parameter jsonString: The JSON string to decode.
    /// - Returns: A decoded BrewInfoResponse.
    /// - Throws: `DecodingError` if the string cannot be converted to UTF-8 or if decoding fails.
    static func decode(from jsonString: String) throws -> BrewInfoResponse {
        guard let data = jsonString.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: [],
                debugDescription: "Could not convert output to UTF-8"
            ))
        }
        let decoder = JSONDecoder()
        return try decoder.decode(BrewInfoResponse.self, from: data)
    }

    /// Array of formulae (command-line tools) in the response.
    let formulae: [Formula]

    /// Array of casks (GUI applications) in the response.
    let casks: [Cask]

    /// Information about a formula (command-line tool) from Homebrew.
    struct Formula: Codable, Sendable {
        let name: String
        let fullName: String
        let tap: String?
        let desc: String?
        let license: String?
        let homepage: String?
        let versions: Versions
        let urls: URLs?
        let installed: [Installed]?
        let dependencies: [String]?
        let optionalDependencies: [String]?
        let buildDependencies: [String]?
        let usedBy: [String]?
        let linkedKeg: String?
        let pinned: Bool?
        let outdated: Bool?

        struct Versions: Codable, Sendable {
            let stable: String?
            let head: String?
            let bottle: Bool?
        }

        struct URLs: Codable, Sendable {
            let stable: StableURL?
            let head: HeadURL?

            struct StableURL: Codable, Sendable {
                let url: String?
            }
            struct HeadURL: Codable, Sendable {
                let url: String?
            }
        }

        struct Installed: Codable, Sendable {
            let version: String
            let installedOnRequest: Bool?
            let installedAsDepency: Bool?

            enum CodingKeys: String, CodingKey {
                case version
                case installedOnRequest = "installed_on_request"
                case installedAsDepency = "installed_as_dependency"
            }
        }

        enum CodingKeys: String, CodingKey {
            case name, desc, license, homepage, versions, urls, installed, pinned, outdated
            case fullName = "full_name"
            case dependencies
            case optionalDependencies = "optional_dependencies"
            case buildDependencies = "build_dependencies"
            case usedBy = "used_by"
            case linkedKeg = "linked_keg"
            case tap
        }
    }

    /// Information about a cask (GUI application) from Homebrew.
    struct Cask: Codable, Sendable {
        /// The cask identifier (used as the package name).
        let token: String

        /// Human-readable names for the cask.
        let name: [String]?

        /// Description of what the cask does.
        let desc: String?

        /// URL to the cask's homepage.
        let homepage: String?

        /// The version string of the cask.
        let version: String?

        /// The installed version string, if installed.
        let installed: String?

        /// Whether this cask has an update available.
        let outdated: Bool?

        /// The Homebrew tap this cask comes from.
        let tap: String?
    }
}

// MARK: - Brew Outdated Response

/// Response structure for `brew outdated --json=v2` commands.
///
/// This structure maps the JSON output from Homebrew's outdated command, which
/// lists packages that have updates available.
nonisolated struct BrewOutdatedResponse: Codable, Sendable {

    /// Decodes a BrewOutdatedResponse from a JSON string.
    ///
    /// - Parameter jsonString: The JSON string to decode.
    /// - Returns: A decoded BrewOutdatedResponse.
    /// - Throws: `DecodingError` if the string cannot be converted to UTF-8 or if decoding fails.
    static func decode(from jsonString: String) throws -> BrewOutdatedResponse {
        guard let data = jsonString.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: [],
                debugDescription: "Could not convert output to UTF-8"
            ))
        }
        let decoder = JSONDecoder()
        return try decoder.decode(BrewOutdatedResponse.self, from: data)
    }

    /// Array of outdated formulae in the response.
    let formulae: [OutdatedFormula]

    /// Array of outdated casks in the response.
    let casks: [OutdatedCask]

    /// Information about an outdated formula.
    struct OutdatedFormula: Codable, Sendable {
        /// The name of the formula.
        let name: String

        /// The currently installed version(s).
        let installedVersions: [String]

        /// The latest available version.
        let currentVersion: String

        /// Whether this formula is pinned.
        let pinned: Bool?

        /// The pinned version, if any.
        let pinnedVersion: String?

        enum CodingKeys: String, CodingKey {
            case name
            case installedVersions = "installed_versions"
            case currentVersion = "current_version"
            case pinned
            case pinnedVersion = "pinned_version"
        }
    }

    /// Information about an outdated cask.
    struct OutdatedCask: Codable, Sendable {
        /// The name of the cask.
        let name: String

        /// The cask identifier token.
        let token: String?

        /// The currently installed version.
        let installedVersions: String?

        /// The latest available version.
        let currentVersion: String?

        enum CodingKeys: String, CodingKey {
            case name, token
            case installedVersions = "installed_versions"
            case currentVersion = "current_version"
        }
    }
}
