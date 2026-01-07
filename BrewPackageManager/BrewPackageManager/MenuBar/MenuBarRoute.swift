//
//  MenuBarRoute.swift
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

/// Defines navigation routes for the menu bar interface.
///
/// This enum represents all possible screens in the menu bar application:
/// - `main`: The primary package list and actions view
/// - `settings`: User preferences and configuration
/// - `help`: Documentation and support information
/// - `packageInfo`: Detailed information for a specific package
/// - `search`: Package search and installation view
/// - `services`: Homebrew services management
/// - `cleanup`: Cache and cleanup management
/// - `dependencies`: Package dependencies viewer
/// - `history`: Operation history
/// - `statistics`: Usage statistics
enum MenuBarRoute: Equatable {
    /// The main package list view.
    case main

    /// The settings panel.
    case settings

    /// The help and documentation view.
    case help

    /// The package detail view with associated package information.
    case packageInfo(BrewPackageInfo)

    /// The package search and installation view.
    case search

    /// The services management view.
    case services

    /// The cleanup and cache management view.
    case cleanup

    /// The dependencies viewer.
    case dependencies

    /// The operation history view.
    case history

    /// The usage statistics view.
    case statistics
}
