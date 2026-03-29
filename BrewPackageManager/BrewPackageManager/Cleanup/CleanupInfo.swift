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
struct CleanupInfo: Sendable, Equatable {

    /// Total cache size in bytes.
    let cacheSize: Int64

    /// Number of cached files.
    let cachedFiles: Int

    /// Number of old package versions that can be cleaned.
    let oldVersions: Int

    /// Display the cache size in a human-readable format.
    var cacheSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)
    }

    /// Whether clearing the download cache is recommended.
    var isCacheCleanupRecommended: Bool {
        cacheSize > 500_000_000
    }

    /// Whether old package versions are taking enough space to recommend cleanup.
    var isOldVersionsCleanupRecommended: Bool {
        oldVersions > 5
    }

    /// Whether any cleanup action is recommended.
    var isCleanupRecommended: Bool {
        isCacheCleanupRecommended || isOldVersionsCleanupRecommended
    }

    /// Short explanation of what the download cache contains.
    var cacheExplanation: String {
        "Temporary downloads that Homebrew keeps in its cache folder. Clearing this frees disk space, but packages may need to be downloaded again later."
    }

    /// Short explanation of what old package versions are.
    var oldVersionsExplanation: String {
        "Previous versions left behind after upgrades in Homebrew's Cellar or Caskroom. Cleaning them does not uninstall the package you use now; it only removes older copies."
    }

    /// Helper text for the cache clear action.
    var clearCacheActionDescription: String {
        "Deletes cached downloads only. Old package versions remain until cleaned separately."
    }

    /// Helper text for the old versions cleanup action.
    var cleanOldVersionsActionDescription: String {
        "Removes previous installed versions kept after upgrades. Your current installed version stays available."
    }

    /// Summary shown after clearing the download cache.
    var oldVersionsRemainingMessage: String {
        switch oldVersions {
        case 0:
            return "No old package versions remain."
        case 1:
            return "1 old package version still remains."
        default:
            return "\(oldVersions) old package versions still remain."
        }
    }
}

extension CleanupInfo {

    /// Create a zero-state cleanup info.
    static var empty: CleanupInfo {
        CleanupInfo(cacheSize: 0, cachedFiles: 0, oldVersions: 0)
    }

    /// Parse cache size from directory listing.
    nonisolated static func parseFromOutput(stdout: String) -> CleanupInfo {
        // Parse output from `brew cleanup --dry-run` or similar.
        // We only count version directories in Cellar/Caskroom here.
        let wouldRemovePrefix = "Would remove: "
        var oldVersions = 0

        let lines = stdout.split(separator: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(wouldRemovePrefix) else { continue }

            let path = trimmed
                .dropFirst(wouldRemovePrefix.count)
                .split(separator: "(", maxSplits: 1, omittingEmptySubsequences: false)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if path.contains("/Cellar/") || path.contains("/Caskroom/") {
                oldVersions += 1
            }
        }

        return CleanupInfo(
            cacheSize: 0,
            cachedFiles: 0,
            oldVersions: oldVersions
        )
    }
}
