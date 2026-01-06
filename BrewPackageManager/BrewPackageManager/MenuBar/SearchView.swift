//
//  SearchView.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//  Version: 1.5.0
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// Search view for finding and installing new packages.
///
/// This view provides a complete package search interface with:
/// - Text-based search with type filtering
/// - Real-time results display
/// - Package installation with confirmation
/// - Progress tracking and error handling
struct SearchView: View {

    // MARK: - Environment

    /// The main packages store.
    @Environment(PackagesStore.self) private var store

    /// User application settings.
    @Environment(AppSettings.self) private var settings

    // MARK: - Properties

    /// Callback to navigate back to main view.
    let onBack: () -> Void

    /// Callback to show package details.
    let onPackageInfo: (SearchResult) -> Void

    // MARK: - State

    /// The current search query text.
    @State private var searchQuery = ""

    /// The package selected for installation.
    @State private var packageToInstall: SearchResult?

    /// Whether the installation confirmation dialog is shown.
    @State private var showInstallConfirmation = false

    // MARK: - Computed Properties

    /// Whether a search is currently in progress.
    private var isSearching: Bool {
        if case .searching = store.searchState { return true }
        return false
    }

    /// Whether search results are loaded.
    private var hasResults: Bool {
        if case .loaded = store.searchState { return true }
        return false
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: .zero) {
            // Header
            PanelHeaderView(title: "Search Packages", onBack: onBack)

            Divider()

            // Search controls
            searchControls

            Divider()

            // Results
            ScrollView {
                VStack(spacing: LayoutConstants.compactSpacing) {
                    switch store.searchState {
                    case .idle:
                        emptyStateView

                    case .searching:
                        loadingView

                    case .loaded(let query, let results, let hasMore):
                        resultsView(query: query, results: results, hasMore: hasMore)

                    case .error(let error):
                        errorView(error: error)
                    }
                }
                .padding(.vertical, LayoutConstants.compactPadding)
            }
        }
        .alert("Install Package", isPresented: $showInstallConfirmation, presenting: packageToInstall) { result in
            installConfirmationActions(for: result)
        } message: { result in
            installConfirmationMessage(for: result)
        }
    }

    // MARK: - Search Controls

    /// Search input and type filter controls.
    private var searchControls: some View {
        VStack(spacing: LayoutConstants.compactSpacing) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search packages...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        performSearch()
                    }

                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        store.clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(LayoutConstants.headerVerticalPadding)
            .background(.quaternary.opacity(0.5))
            .cornerRadius(LayoutConstants.hoverCornerRadius)
            .padding(.horizontal)

            // Type filter
            Picker("Type", selection: Binding(
                get: { store.searchTypeFilter },
                set: { store.searchTypeFilter = $0 }
            )) {
                Text("All").tag(nil as PackageType?)
                Text("Formulae").tag(PackageType.formula as PackageType?)
                Text("Casks").tag(PackageType.cask as PackageType?)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: store.searchTypeFilter) { _, _ in
                if !searchQuery.isEmpty {
                    performSearch()
                }
            }
        }
        .padding(.vertical, LayoutConstants.compactPadding)
    }

    // MARK: - Content Views

    /// Empty state shown when no search has been performed.
    private var emptyStateView: some View {
        VStack(spacing: LayoutConstants.sectionSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Search for Packages")
                .font(.headline)

            Text("Enter a package name to search Homebrew")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    /// Loading indicator shown during search.
    private var loadingView: some View {
        VStack(spacing: LayoutConstants.sectionSpacing) {
            ProgressView()
            Text("Searching...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    /// Results list view.
    private func resultsView(query: String, results: [SearchResult], hasMore: Bool) -> some View {
        VStack(spacing: .zero) {
            if results.isEmpty {
                noResultsView(query: query)
            } else {
                ForEach(results) { result in
                    SearchResultRow(
                        result: result,
                        operation: store.installOperations[result.name],
                        onInstall: {
                            packageToInstall = result
                            showInstallConfirmation = true
                        },
                        onShowInfo: {
                            onPackageInfo(result)
                        }
                    )

                    if result.id != results.last?.id {
                        Divider()
                            .padding(.leading, 40)
                    }
                }

                if hasMore {
                    moreResultsHint(query: query)
                }
            }
        }
    }

    /// No results message.
    private func noResultsView(query: String) -> some View {
        VStack(spacing: LayoutConstants.sectionSpacing) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Results")
                .font(.headline)

            Text("No packages found matching '\(query)'")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    /// Error view with retry option.
    private func errorView(error: AppError) -> some View {
        VStack(spacing: LayoutConstants.sectionSpacing) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Search Failed")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                performSearch()
            }
        }
        .padding()
    }

    /// Hint shown when more results are available.
    private func moreResultsHint(query: String) -> some View {
        VStack(spacing: LayoutConstants.compactSpacing) {
            Divider()

            Text("More results available")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Refine your search to see more specific results")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, LayoutConstants.headerVerticalPadding)
    }

    // MARK: - Install Confirmation

    /// Actions for the installation confirmation dialog.
    private func installConfirmationActions(for result: SearchResult) -> some View {
        Group {
            Button("Cancel", role: .cancel) {}

            Button("Install") {
                Task {
                    await store.installPackage(result, debugMode: settings.debugMode)
                }
            }
        }
    }

    /// Message content for the installation confirmation dialog.
    private func installConfirmationMessage(for result: SearchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Install \(result.name)?")
                .font(.headline)

            if let info = result.info, let desc = info.desc {
                Text(desc)
                    .font(.subheadline)
            } else {
                Text("This will install the \(result.type.label.lowercased()) '\(result.name)'")
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Actions

    /// Performs a search with the current query.
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }

        Task {
            await store.search(query: searchQuery, debugMode: settings.debugMode)
        }
    }
}
