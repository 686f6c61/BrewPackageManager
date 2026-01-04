//
//  AppKitBridge.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import AppKit

/// Provides isolated AppKit functionality for SwiftUI views.
///
/// This enum centralizes all AppKit interactions in one place to minimize
/// framework mixing between SwiftUI and AppKit. All methods are marked
/// `@MainActor` to ensure they run on the main thread as required by AppKit.
///
/// Provides utilities for:
/// - Clipboard operations
/// - Finder integration
/// - Application lifecycle management
@MainActor
enum AppKitBridge {

    // MARK: - Methods

    /// Copies a string to the system clipboard.
    ///
    /// - Parameter string: The text to copy to the clipboard.
    static func copyToClipboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    /// Reveals a file in Finder at the specified location.
    ///
    /// - Parameter url: The file URL to reveal in Finder.
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Terminates the application.
    static func quit() {
        NSApplication.shared.terminate(nil)
    }
}
