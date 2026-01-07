//
//  CleanupInfo.swift
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

/// Information about cleanup and cache status.
///
/// Contains disk space usage for Homebrew's cache, downloads,
/// and other temporary files that can be cleaned up.
struct CleanupInfo: Sendable {

    /// Total cache size in bytes.
    let cacheSize: Int64

    /// Number of cached files.
    let cachedFiles: Int

    /// Number of old formula versions that can be cleaned.
    let oldVersions: Int

    /// Display the cache size in a human-readable format.
    var cacheSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)
    }

    /// Whether cleanup is recommended (cache > 500 MB or old versions > 5).
    var isCleanupRecommended: Bool {
        cacheSize > 500_000_000 || oldVersions > 5
    }
}

extension CleanupInfo {

    /// Create a zero-state cleanup info.
    static var empty: CleanupInfo {
        CleanupInfo(cacheSize: 0, cachedFiles: 0, oldVersions: 0)
    }

    /// Parse cache size from directory listing.
    nonisolated static func parseFromOutput(stdout: String) -> CleanupInfo {
        // Parse output from `brew cleanup --dry-run` or similar
        let cacheSize: Int64 = 0
        var cachedFiles = 0
        var oldVersions = 0

        let lines = stdout.split(separator: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Count old versions (lines that mention "would remove")
            if trimmed.contains("Would remove:") || trimmed.contains("would remove") {
                oldVersions += 1
            }

            // Try to extract file sizes (basic parsing)
            if trimmed.contains("KB") || trimmed.contains("MB") || trimmed.contains("GB") {
                cachedFiles += 1
            }
        }

        return CleanupInfo(
            cacheSize: cacheSize,
            cachedFiles: cachedFiles,
            oldVersions: oldVersions
        )
    }
}
