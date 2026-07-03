//
//  PackageRow.swift
//  BrewPackageManager
//
//  Fila de paquete con actualización pendiente y menú contextual de acciones.
//

import SwiftUI

struct PackageRow: View {
    let package: BrewPackage
    let actionTitle: String
    let secondaryTitle: String
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(package.displayName)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    StatusBadge(text: package.type.label, tint: package.type.tint)
                    if let currentVersion = package.currentVersion {
                        Text("\(package.installedVersion) → \(currentVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let desc = package.desc, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Menu {
                Button(actionTitle, action: primaryAction)
                Button(secondaryTitle, action: secondaryAction)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Actions for \(package.displayName)")
        }
        .card()
    }
}
