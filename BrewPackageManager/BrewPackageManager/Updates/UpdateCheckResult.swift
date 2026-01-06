//
//  UpdateCheckResult.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//  Version: 1.6.0
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

/// Result of checking for application updates.
enum UpdateCheckResult: Sendable {
    /// Application is up to date
    case upToDate

    /// Update is available
    case updateAvailable(ReleaseInfo)

    /// Error occurred during check
    case error(AppError)
}
