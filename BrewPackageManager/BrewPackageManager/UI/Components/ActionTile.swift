//
//  ActionTile.swift
//  BrewPackageManager
//
//  Botón de acceso rápido en rejilla (icono, título y subtítulo).
//

import SwiftUI

struct ActionTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .cardChrome()
    }
}
