//
//  ErrorView.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// The error view displayed when package operations fail.
///
/// This view shows:
/// - Error icon (red exclamation triangle)
/// - Localized error description
/// - Recovery suggestion (if available)
///
/// The error display supports multi-line text and centers all content.
struct ErrorView: View {

    // MARK: - Properties

    /// The error to display.
    let error: AppError

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text(error.localizedDescription)
                .font(.headline)
                .multilineTextAlignment(.center)

            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
