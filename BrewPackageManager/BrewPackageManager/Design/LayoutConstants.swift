//
//  LayoutConstants.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// Centralized layout constants for consistent UI dimensions and spacing.
///
/// This enum provides all layout values used throughout the application,
/// ensuring visual consistency and making it easy to adjust the design system.
enum LayoutConstants {

    // MARK: - Width Constants

    /// Width of the main package list menu.
    static let mainMenuWidth: CGFloat = 380

    /// Width of the settings panel.
    static let settingsMenuWidth: CGFloat = 280

    /// Width of the package info detail panel.
    static let serviceInfoMenuWidth: CGFloat = 280

    /// Standard menu width (legacy).
    static let menuWidth: CGFloat = 320

    /// Width of domain picker components.
    static let domainPickerWidth: CGFloat = 140

    /// Width of seconds input fields.
    static let secondsFieldWidth: CGFloat = 60

    // MARK: - Icon and Image Sizes

    /// Width of icons in menu rows.
    static let menuRowIconWidth: CGFloat = 20

    // MARK: - Padding Constants

    /// Vertical padding for header sections.
    static let headerVerticalPadding: CGFloat = 8

    /// Standard horizontal padding for section containers.
    static let sectionContainerHorizontalPadding: CGFloat = 4

    /// Horizontal padding for status badges.
    static let statusBadgeHorizontalPadding: CGFloat = 6

    /// Vertical padding for status badges.
    static let statusBadgeVerticalPadding: CGFloat = 2

    // MARK: - Spacing Constants

    /// Standard spacing between sections.
    static let sectionSpacing: CGFloat = 16

    /// Tight spacing for closely related elements.
    static let tightSpacing: CGFloat = 2

    /// Compact spacing for condensed layouts.
    static let compactSpacing: CGFloat = 4

    /// Compact padding for condensed layouts.
    static let compactPadding: CGFloat = 4

    // MARK: - Preview Dimensions

    /// Width for preview sections in SwiftUI previews.
    static let previewSectionWidth: CGFloat = 300

    /// Width for glass effect previews.
    static let previewGlassWidth: CGFloat = 200

    /// Height for glass effect previews.
    static let previewGlassHeight: CGFloat = 100

    /// Height for panel previews.
    static let previewPanelHeight: CGFloat = 200

    /// Spacing in preview layouts.
    static let previewSpacing: CGFloat = 20

    // MARK: - Corner Radius Constants

    /// Corner radius for glass background effects.
    static let glassCornerRadius: CGFloat = 8

    /// Corner radius for hover highlight effects.
    static let hoverCornerRadius: CGFloat = 6

    /// Corner radius for section containers.
    static let sectionContainerCornerRadius: CGFloat = 10

    /// Corner radius for panel views.
    static let panelCornerRadius: CGFloat = 12

    /// Shadow radius for panels.
    static let panelShadowRadius: CGFloat = 10

    // MARK: - Opacity Constants

    /// Tint opacity for header status pills.
    static let headerStatusPillTintOpacity: CGFloat = 0.18

    // MARK: - Effect Constants

    /// Glow radius for status indicators.
    static let statusIndicatorGlowRadius: CGFloat = 4

    // MARK: - Modern UI Elements

    /// Height of accent bars.
    static let accentBarHeight: CGFloat = 3

    /// Top padding for section labels.
    static let sectionLabelTopPadding: CGFloat = 12

    /// Bottom padding for section labels.
    static let sectionLabelBottomPadding: CGFloat = 4

    /// Size of disclosure indicator chevrons.
    static let disclosureIndicatorSize: CGFloat = 10

    /// Scale factor for hover press effects (slightly smaller = 0.98).
    static let hoverScaleEffect: CGFloat = 0.98
}
