//
//  SearchState.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//  Version: 1.5.0
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

/// The loading state of package search operations.
///
/// This enum represents all possible states during a package search workflow:
/// - `idle`: No search has been performed or the search was cleared
/// - `searching`: A search operation is currently in progress
/// - `loaded`: Search completed successfully with results
/// - `error`: The search operation failed
///
/// The `loaded` case includes the original query, results array, and a flag
/// indicating whether more results are available (triggering the "refine search" hint).
nonisolated enum SearchState: Sendable {

    // MARK: - Cases

    /// No search has been performed yet.
    ///
    /// This is the initial state and the state after clearing search results.
    case idle

    /// A search operation is currently in progress.
    ///
    /// - Parameter query: The search term being queried.
    case searching(query: String)

    /// Search completed successfully with results.
    ///
    /// - Parameters:
    ///   - query: The search term that was queried.
    ///   - results: Array of search results (limited to first page).
    ///   - hasMore: Whether additional results are available beyond the displayed page.
    case loaded(query: String, results: [SearchResult], hasMore: Bool)

    /// The search operation failed with an error.
    ///
    /// - Parameter error: The error that occurred during the search.
    case error(AppError)
}
