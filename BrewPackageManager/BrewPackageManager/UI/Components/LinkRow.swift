//
//  LinkRow.swift
//  BrewPackageManager
//
//  Fila que abre una URL externa en el navegador predeterminado.
//

import AppKit
import SwiftUI

struct LinkRow: View {
    let title: String
    let subtitle: String
    let urlString: String

    var body: some View {
        Button {
            guard let url = URL(string: urlString) else { return }
            NSWorkspace.shared.open(url)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .card()
        }
        .buttonStyle(.plain)
    }
}
