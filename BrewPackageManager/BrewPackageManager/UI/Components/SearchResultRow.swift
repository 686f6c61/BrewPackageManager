//
//  SearchResultRow.swift
//  BrewPackageManager
//
//  Fila de resultado de búsqueda con instalación directa y acceso al detalle.
//

import SwiftUI

struct SearchResultRow: View {
    let result: SearchResult
    let operation: PackageOperation?
    let installAction: () -> Void
    let detailsAction: () -> Void

    private var isInstalling: Bool {
        operation?.status == .running
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(result.name)
                    .font(.subheadline.weight(.semibold))
                StatusBadge(text: result.type.label, tint: result.type.tint)
                if result.isInstalled {
                    StatusBadge(text: "Installed", tint: AppTheme.statusPositive)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                Button("Details", action: detailsAction)
                    .buttonStyle(.bordered)
                if !result.isInstalled {
                    Button(isInstalling ? "Installing…" : "Install", action: installAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(isInstalling)
                }
                if isInstalling {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .controlSize(.small)
            if let diagnostics = operation?.diagnostics, !diagnostics.isEmpty {
                Text(diagnostics)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}
