//
//  SectionHeader.swift
//  BrewPackageManager
//
//  Cabecera de sección con título y detalle opcional en tipografía del sistema.
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
