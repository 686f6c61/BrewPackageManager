//
//  InventoryRow.swift
//  BrewPackageManager
//
//  Fila compacta del inventario instalado; toca para abrir el detalle.
//

import SwiftUI

struct InventoryRow: View {
    let package: BrewPackage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: package.type.systemImage)
                    .foregroundStyle(package.type.tint)
                    .frame(width: 24, height: 24)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(package.displayName)
                        .font(.subheadline.weight(.medium))
                    Text(package.installedVersion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .card()
        }
        .buttonStyle(.plain)
        // El tipo de paquete solo se distingue por icono y color; la etiqueta
        // lo hace explícito para VoiceOver.
        .accessibilityLabel("\(package.displayName), \(package.type.label), version \(package.installedVersion)")
    }
}
