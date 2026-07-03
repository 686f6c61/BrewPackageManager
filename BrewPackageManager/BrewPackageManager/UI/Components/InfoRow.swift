//
//  InfoRow.swift
//  BrewPackageManager
//
//  Par etiqueta/valor con el valor seleccionable (licencias, rutas, URLs).
//

import SwiftUI

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
        }
    }
}
