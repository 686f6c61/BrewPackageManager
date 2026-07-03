//
//  AppTheme.swift
//  BrewPackageManager
//
//  Tokens visuales de la interfaz nativa. Filosofía: el sistema decide los
//  colores base (claro/oscuro, acento del usuario, contraste aumentado);
//  la app solo aporta geometría compartida y semántica de estado.
//

import SwiftUI

enum AppTheme {
    // Dimensiones del popover de la barra de menús.
    static let popoverWidth: CGFloat = 380
    static let popoverHeight: CGFloat = 560

    // Dimensiones mínimas del modo ventana (barra lateral + contenido).
    static let windowMinWidth: CGFloat = 760
    static let windowMinHeight: CGFloat = 560

    // Geometría compartida.
    static let cornerRadius: CGFloat = 12
    static let pagePadding: CGFloat = 14
    static let sectionSpacing: CGFloat = 14

    // Semáforo de estado. Colores del sistema: se adaptan solos
    // a claro/oscuro y a la preferencia de contraste.
    static let statusPositive: Color = .green
    static let statusPending: Color = .orange
    static let statusCritical: Color = .red

    /// Rejilla de dos columnas usada por las pantallas con azulejos de acción.
    static let twoColumnGrid: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
}

extension PackageType {
    /// Tinte semántico por tipo de paquete: azul para fórmulas, morado para
    /// casks. Único punto de verdad para las filas que distinguen el tipo.
    var tint: Color {
        self == .formula ? .blue : .purple
    }
}

/// Fondo y borde de tarjeta nativos (sin padding). Lo comparten `card()` y
/// los componentes que aplican el chrome sobre otra estructura, como los
/// botones de azulejo.
struct CardChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 1)
            )
    }
}

/// Tarjeta nativa completa: padding estándar más el chrome compartido,
/// en lugar de los grises calibrados fijos del tema anterior.
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardChrome()
    }
}

extension View {
    /// Aplica el estilo de tarjeta compartido por todas las pantallas.
    func card() -> some View {
        modifier(CardModifier())
    }

    /// Aplica solo el fondo y borde de tarjeta, sin padding.
    func cardChrome() -> some View {
        modifier(CardChromeModifier())
    }
}
