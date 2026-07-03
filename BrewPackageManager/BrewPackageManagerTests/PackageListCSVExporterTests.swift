//
//  PackageListCSVExporterTests.swift
//  BrewPackageManagerTests
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//
//  Tests del exportador CSV de listados de paquetes.
//

import Foundation
import Testing
@testable import BrewPackageManager

@Suite("PackageListCSVExporter")
struct PackageListCSVExporterTests {

    /// Construye un paquete mínimo para los tests, variando solo lo relevante.
    private func makePackage(
        name: String,
        desc: String? = nil,
        isOutdated: Bool = false
    ) -> BrewPackage {
        BrewPackage(
            name: name,
            fullName: name,
            desc: desc,
            homepage: nil,
            type: .formula,
            installedVersion: "1.0.0",
            currentVersion: isOutdated ? "2.0.0" : nil,
            isOutdated: isOutdated,
            pinnedVersion: nil,
            tap: nil
        )
    }

    @Test("La cabecera y una fila simple se generan sin escapado")
    func simpleRow() {
        let csv = PackageListCSVExporter.csv(from: [makePackage(name: "wget")])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines[0] == "Name,Full Name,Type,Installed Version,Current Version,Outdated,Tap,Description,Homepage")
        #expect(lines[1].hasPrefix("wget,wget,formula,1.0.0,"))
        #expect(lines[1].contains(",No,"))
    }

    @Test("Los campos con comas, comillas o saltos de línea se escapan")
    func escapedFields() {
        let csv = PackageListCSVExporter.csv(from: [
            makePackage(name: "jq", desc: "a \"json\" tool, fast")
        ])
        #expect(csv.contains("\"a \"\"json\"\" tool, fast\""))
    }

    @Test("Los paquetes desactualizados se marcan con Yes")
    func outdatedFlag() {
        let csv = PackageListCSVExporter.csv(from: [makePackage(name: "old", isOutdated: true)])
        #expect(csv.contains(",Yes,"))
    }
}
