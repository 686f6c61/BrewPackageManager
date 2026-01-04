//
//  PackagesDiskCache.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

/// Manages persistent caching of package data to disk.
///
/// This utility stores package information in the Application Support directory
/// to provide faster startup times by avoiding unnecessary Homebrew queries.
nonisolated enum PackagesDiskCache {

    // MARK: - Properties

    /// Cache format version for invalidation when structure changes.
    private static let cacheVersion = 1

    // MARK: - Types

    /// Structure representing cached package data.
    struct CachedPackages: Codable, Sendable {
        /// The cached packages.
        let packages: [BrewPackage]

        /// When the cache was last refreshed.
        let lastRefresh: Date?
    }

    // MARK: - Public Methods

    /// Loads cached packages from disk.
    ///
    /// - Returns: The cached packages, or `nil` if the cache doesn't exist or is invalid.
    static func load() -> CachedPackages? {
        let url = cacheURL()

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CachedPackages.self, from: data)
        } catch {
            return nil
        }
    }

    /// Saves packages to the disk cache.
    ///
    /// Creates the necessary directories if they don't exist and writes the
    /// cached data atomically to prevent corruption.
    ///
    /// - Parameters:
    ///   - packages: The packages to cache.
    ///   - lastRefresh: The timestamp of the last refresh.
    /// - Throws: File system errors if the cache cannot be written.
    static func save(packages: [BrewPackage], lastRefresh: Date?) throws {
        let url = cacheURL()
        let cached = CachedPackages(packages: packages, lastRefresh: lastRefresh)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(cached)

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try data.write(to: url, options: [.atomic])
    }

    // MARK: - Private Methods

    /// Constructs the URL for the cache file.
    ///
    /// The cache is stored in the Application Support directory under a subdirectory
    /// specific to this app. The filename includes the cache version for easy invalidation.
    ///
    /// - Returns: The URL where the cache file should be stored.
    private static func cacheURL() -> URL {
        let base = URL.applicationSupportDirectory
        let hostIdentifier = (Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName)
            .replacing("/", with: "_")

        let directory = base
            .appending(path: "BrewPackageManager", directoryHint: .isDirectory)
            .appending(path: hostIdentifier, directoryHint: .isDirectory)

        return directory.appending(path: "packages-cache-v\(cacheVersion).json")
    }
}
