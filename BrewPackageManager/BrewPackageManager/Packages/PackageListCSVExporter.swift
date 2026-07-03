//
//  PackageListCSVExporter.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import Foundation

/// Exporta listados de paquetes a formato CSV.
///
/// Tipo sin estado: recibe el snapshot de paquetes y devuelve el CSV con
/// cabecera fija y escapado RFC 4180 (comas, comillas y saltos de línea).
/// Es `nonisolated` porque no toca estado de UI y así puede usarse desde
/// cualquier contexto de concurrencia.
nonisolated enum PackageListCSVExporter {

    /// Genera el CSV completo, cabecera incluida, para la lista dada.
    ///
    /// - Parameter packages: Los paquetes a exportar, en el orden recibido.
    /// - Returns: Cadena CSV con una fila por paquete.
    static func csv(from packages: [BrewPackage]) -> String {
        var csv = "Name,Full Name,Type,Installed Version,Current Version,Outdated,Tap,Description,Homepage\n"

        for package in packages {
            let fields = [
                package.name,
                package.fullName,
                package.type.rawValue,
                package.installedVersion,
                package.currentVersion ?? "",
                package.isOutdated ? "Yes" : "No",
                package.tap ?? "",
                package.desc ?? "",
                package.homepage ?? ""
            ]
            csv += fields.map(escape).joined(separator: ",") + "\n"
        }

        return csv
    }

    /// Escapa un valor individual según RFC 4180.
    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacing("\"", with: "\"\""))\""
        }
        return value
    }
}
