//
//  ServicesView.swift
//  BrewPackageManager
//
//  Created by 686f6c61
//  Repository: https://github.com/686f6c61/BrewPackageManager
//  Version: 1.7.0
//
//  A native macOS menu bar application for managing Homebrew packages.
//  Built with Swift and SwiftUI.
//

import SwiftUI

/// View for managing Homebrew services.
///
/// Displays a list of all Homebrew services with their current status
/// and provides controls to start, stop, and restart services.
struct ServicesView: View {

    // MARK: - Properties

    /// Callback to dismiss the view and return to main menu.
    let onDismiss: () -> Void

    // MARK: - State

    /// Services store for managing service operations.
    @State private var servicesStore = ServicesStore()

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            PanelHeaderView(title: "Services", onBack: onDismiss)

            Divider()

            if servicesStore.isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading services...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if servicesStore.services.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "gear.badge.xmark")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No Services Found")
                        .font(.headline)
                    Text("No Homebrew services are installed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Summary section
                        HStack(spacing: 16) {
                            StatusBadge(
                                count: servicesStore.runningCount,
                                label: "Running",
                                color: .green
                            )
                            StatusBadge(
                                count: servicesStore.stoppedCount,
                                label: "Stopped",
                                color: .secondary
                            )
                        }
                        .padding()
                        .sectionContainer()

                        // Services list
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(servicesStore.services) { service in
                                ServiceRow(
                                    service: service,
                                    isOperating: servicesStore.isOperating,
                                    onStart: { await servicesStore.startService(service) },
                                    onStop: { await servicesStore.stopService(service) },
                                    onRestart: { await servicesStore.restartService(service) }
                                )

                                if service.id != servicesStore.services.last?.id {
                                    Divider()
                                        .padding(.leading, 12)
                                }
                            }
                        }
                        .sectionContainer()
                    }
                    .padding()
                }
                .frame(maxHeight: 440)
            }
        }
        .frame(width: LayoutConstants.mainMenuWidth)
        .onAppear {
            // Only fetch if we don't have data and aren't already loading
            if servicesStore.services.isEmpty && !servicesStore.isLoading {
                Task {
                    await servicesStore.fetchServices()
                }
            }
        }
        .alert("Error", isPresented: .init(
            get: { servicesStore.lastError != nil },
            set: { if !$0 { servicesStore.lastError = nil } }
        )) {
            Button("OK") { servicesStore.lastError = nil }
        } message: {
            if let error = servicesStore.lastError {
                Text(error.localizedDescription)
            }
        }
    }
}

// MARK: - StatusBadge

/// Badge displaying a count and label for service status.
struct StatusBadge: View {

    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(count)")
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - ServiceRow

/// Row displaying a single service with controls.
struct ServiceRow: View {

    let service: BrewService
    let isOperating: Bool
    let onStart: () async -> Void
    let onStop: () async -> Void
    let onRestart: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Service name and status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        Text(service.status.displayText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if let pid = service.pid {
                            Text("• PID: \(pid)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Action buttons
                HStack(spacing: 8) {
                    if service.status == .stopped || service.status == .error {
                        ServiceButton(
                            systemImage: "play.fill",
                            isDisabled: isOperating,
                            action: onStart
                        )
                    }

                    if service.status == .started {
                        ServiceButton(
                            systemImage: "stop.fill",
                            isDisabled: isOperating,
                            action: onStop
                        )
                        ServiceButton(
                            systemImage: "arrow.clockwise",
                            isDisabled: isOperating,
                            action: onRestart
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statusColor: Color {
        switch service.status {
        case .started: return .green
        case .stopped: return .secondary
        case .error: return .red
        case .unknown: return .orange
        }
    }
}

// MARK: - ServiceButton

/// Button for service actions (start, stop, restart).
struct ServiceButton: View {

    let systemImage: String
    let isDisabled: Bool
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            Image(systemName: systemImage)
                .font(.caption)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(isDisabled)
    }
}
