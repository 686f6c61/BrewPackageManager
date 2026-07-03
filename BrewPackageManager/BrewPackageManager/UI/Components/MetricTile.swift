//
//  MetricTile.swift
//  BrewPackageManager
//
//  Métrica compacta (título + valor) para las cabeceras de pantalla.
//

import SwiftUI

struct MetricTile: View {
    let title: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
