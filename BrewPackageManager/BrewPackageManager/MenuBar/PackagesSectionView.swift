//
//  PackagesSectionView.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// The packages list section view.
///
/// This view manages the display of Homebrew packages with:
/// - Section header with "Outdated only" toggle
/// - Loading state with progress indicator
/// - Error state with error details
/// - Empty state when no packages match criteria
/// - Scrollable list of packages
///
/// The "Outdated only" toggle filters the list to show only packages
/// with available updates, controlled by user settings.
struct PackagesSectionView: View {

    // MARK: - Environment

    /// The main packages store.
    @Environment(PackagesStore.self) private var store

    /// User application settings.
    @Environment(AppSettings.self) private var settings

    // MARK: - Properties

    /// Callback invoked when the user taps the info button for a package.
    let onPackageInfo: (BrewPackage) -> Void

    // MARK: - Computed Properties

    /// Returns the packages to display based on the "Outdated only" setting.
    private var displayedPackages: [BrewPackage] {
        if settings.onlyShowOutdated {
            return store.outdatedPackages
        }
        return store.packages
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            HStack {
                MenuSectionLabel(title: "Packages")

                Spacer()

                Toggle(isOn: Binding(
                    get: { settings.onlyShowOutdated },
                    set: { settings.onlyShowOutdated = $0 }
                )) {
                    Text("Outdated only")
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .padding(.trailing)
            }

            if store.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .padding()
            } else if let error = store.error {
                ErrorView(error: error)
                    .padding()
            } else if displayedPackages.isEmpty {
                EmptyStateView()
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(displayedPackages) { package in
                            PackageMenuItemView(
                                package: package,
                                onInfo: { onPackageInfo(package) }
                            )
                        }
                    }
                }
                .frame(minHeight: 500, maxHeight: 600)
            }
        }
    }
}
