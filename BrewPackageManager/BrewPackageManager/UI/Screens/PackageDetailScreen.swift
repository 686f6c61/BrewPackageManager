//
//  PackageDetailScreen.swift
//  BrewPackageManager
//
//  Detalle de un paquete: versiones, licencia, homepage y enlaces externos.
//

import AppKit
import SwiftUI

struct PackageDetailScreen: View {
    let info: BrewPackageInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: info.name, detail: info.fullName)
                    if let description = info.desc {
                        Text(description)
                            .font(.callout)
                    }
                    HStack(spacing: 8) {
                        MetricTile(title: "Stable", value: info.versions.stable ?? "–")
                        MetricTile(
                            title: "Installed",
                            value: info.installedVersions?.first?.version ?? "–",
                            tint: AppTheme.statusPositive
                        )
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 10) {
                    if let license = info.license {
                        InfoRow(label: "License", value: license)
                    }
                    if let homepage = info.homepage {
                        InfoRow(label: "Homepage", value: homepage)
                    }
                    if let linkedKeg = info.linkedKeg {
                        InfoRow(label: "Linked keg", value: linkedKeg)
                    }
                }
                .card()

                HStack(spacing: 8) {
                    if let homepageURL = safeWebURL(from: info.homepage) {
                        Button("Open homepage", systemImage: "link") {
                            NSWorkspace.shared.open(homepageURL)
                        }
                    }
                    if let changelogURL = info.changelogURL, isWebURL(changelogURL) {
                        Button("Releases", systemImage: "arrow.up.right.square") {
                            NSWorkspace.shared.open(changelogURL)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(AppTheme.pagePadding)
        }
        .navigationTitle(info.name)
    }

    /// Solo se abren URLs web reales: los metadatos del paquete vienen del
    /// JSON de brew y no deben poder lanzar esquemas arbitrarios (file:, etc.).
    private func safeWebURL(from string: String?) -> URL? {
        guard let string, let url = URL(string: string), isWebURL(url) else {
            return nil
        }
        return url
    }

    private func isWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
