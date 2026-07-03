//
//  StatusBadge.swift
//  BrewPackageManager
//
//  Distintivo de estado en cápsula con tinte semántico discreto.
//

import SwiftUI

struct StatusBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15), in: Capsule())
            // El tinte puro no alcanza 4,5:1 sobre fondo claro; mezclarlo con
            // el color primario lo oscurece en claro y lo aclara en oscuro,
            // manteniendo la semántica y cumpliendo contraste en ambos modos.
            .foregroundStyle(tint.mix(with: .primary, by: 0.45))
    }
}
