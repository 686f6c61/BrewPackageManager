//
//  AppUpdateStore.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation
import Observation
import OSLog

/// Gestiona la comprobación de actualizaciones de la propia aplicación.
///
/// Consulta la última release publicada en GitHub a través de `UpdateChecker`
/// y expone el resultado para que la UI ofrezca la descarga o confirme que
/// la app está al día.
@MainActor
@Observable
final class AppUpdateStore {

    /// Logger para trazar las comprobaciones de actualización.
    private let logger = Logger(subsystem: "BrewPackageManager", category: "AppUpdateStore")

    /// Cliente que consulta las releases publicadas.
    private let updateChecker = UpdateChecker()

    /// Resultado de la última comprobación, si la hay.
    var updateCheckResult: UpdateCheckResult?

    /// Indica si hay una comprobación en curso.
    var isCheckingForUpdates = false

    /// Comprueba si hay una versión más reciente de la aplicación.
    ///
    /// Obtiene la última release de GitHub y la compara con la versión
    /// actual del bundle. El resultado queda en `updateCheckResult`.
    ///
    /// - Parameters:
    ///   - settings: Ajustes de la app (versión omitida y marca temporal).
    ///   - manual: Si la comprobación la inició el usuario explícitamente.
    func checkForUpdates(settings: AppSettings, manual: Bool = false) async {
        guard !isCheckingForUpdates else {
            logger.info("Update check already in progress")
            return
        }

        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }

        // Get current version from bundle
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            logger.error("Could not read current version from bundle")
            updateCheckResult = .error(.updateCheckFailed(reason: "Could not read app version"))
            return
        }

        logger.info("Checking for updates (current version: \(currentVersion))...")

        let result = await updateChecker.checkForUpdates(
            currentVersion: currentVersion,
            skippedVersion: settings.skippedVersion
        )

        updateCheckResult = result
        settings.lastUpdateCheck = Date()

        // Log result
        switch result {
        case .upToDate:
            logger.info("App is up to date")
        case .updateAvailable(let release):
            logger.info("Update available: \(release.version)")
        case .error(let error):
            logger.error("Update check failed: \(error.localizedDescription)")
        }
    }
}
