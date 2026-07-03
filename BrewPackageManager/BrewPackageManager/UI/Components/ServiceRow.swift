//
//  ServiceRow.swift
//  BrewPackageManager
//
//  Fila de servicio: solo muestra las acciones válidas para su estado actual.
//

import SwiftUI

struct ServiceRow: View {
    let service: BrewService
    let operationState: ServicesStore.ServiceOperationState
    let onStart: () async -> Void
    let onStop: () async -> Void
    let onRestart: () async -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    StatusBadge(text: service.status.displayText, tint: statusTint)
                    if let pid = service.pid {
                        Text("PID \(pid)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !service.metadataSummary.isEmpty {
                    Text(service.metadataSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let operationMessage {
                    Text(operationMessage)
                        .font(.caption)
                        .foregroundStyle(operationTint)
                }
            }
            Spacer()
            if isRunningOperation {
                ProgressView()
                    .controlSize(.small)
            } else {
                HStack(spacing: 8) {
                    if service.status == .stopped || service.status == .error {
                        Button {
                            Task { await onStart() }
                        } label: {
                            Image(systemName: "play.fill")
                        }
                        .help("Start service")
                        .accessibilityLabel("Start \(service.name)")
                    }
                    if service.status == .started {
                        Button {
                            Task { await onStop() }
                        } label: {
                            Image(systemName: "stop.fill")
                        }
                        .help("Stop service")
                        .accessibilityLabel("Stop \(service.name)")
                        Button {
                            Task { await onRestart() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Restart service")
                        .accessibilityLabel("Restart \(service.name)")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .card()
    }

    private var statusTint: Color {
        switch service.status {
        case .started: return AppTheme.statusPositive
        case .stopped: return AppTheme.statusPending
        case .error: return AppTheme.statusCritical
        case .unknown: return .purple
        }
    }

    private var isRunningOperation: Bool {
        if case .running = operationState { return true }
        return false
    }

    private var operationMessage: String? {
        switch operationState {
        case .idle: return nil
        case .running(let action): return "\(action.displayName) \(service.name)…"
        case .succeeded(_, let message): return message
        case .failed(_, let error): return error.localizedDescription
        }
    }

    private var operationTint: Color {
        switch operationState {
        case .idle: return .secondary
        case .running: return .blue
        case .succeeded: return AppTheme.statusPositive
        case .failed: return AppTheme.statusCritical
        }
    }
}
