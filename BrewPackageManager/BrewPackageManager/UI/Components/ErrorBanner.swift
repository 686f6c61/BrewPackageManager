//
//  ErrorBanner.swift
//  BrewPackageManager
//
//  Aviso de error contextual dentro de la pantalla afectada. Sustituye a las
//  alertas modales genéricas «Warning»/«Error» de la interfaz anterior.
//

import SwiftUI

struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void
    var retry: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.statusPending)
            Text(message)
                .font(.caption)
            Spacer(minLength: 8)
            if let retry {
                Button("Retry", action: retry)
                    .controlSize(.small)
            }
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error")
        }
        .padding(10)
        .background(
            AppTheme.statusPending.opacity(0.12),
            in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
        )
    }
}
