//
//  SettingsScreen.swift
//  BrewPackageManager
//
//  Preferencias con Form en estilo agrupado, el aspecto estándar de los
//  paneles de ajustes en macOS moderno.
//

import SwiftUI

struct SettingsScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PackagesStore.self) private var store

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                Toggle("Automatic app update checks", isOn: $settings.checkForUpdatesEnabled)
            }
            Section("Packages") {
                Toggle("Show only outdated packages", isOn: $settings.onlyShowOutdated)
                Toggle("Debug mode", isOn: $settings.debugMode)
                LabeledContent("Auto-refresh interval (seconds)") {
                    TextField(
                        "Seconds",
                        // Los valores negativos no tienen significado: se
                        // normalizan a 0, que desactiva el refresco automático.
                        value: Binding(
                            get: { settings.autoRefreshInterval },
                            set: { settings.autoRefreshInterval = max(0, $0) }
                        ),
                        format: .number
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .labelsHidden()
                }
                Text("Set to 0 to disable automatic refreshes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("App Updates") {
                Button(store.appUpdates.isCheckingForUpdates ? "Checking…" : "Check for app updates now") {
                    Task { await store.appUpdates.checkForUpdates(settings: settings, manual: true) }
                }
                .disabled(store.appUpdates.isCheckingForUpdates)
                if let feedback = updateFeedback {
                    Text(feedback)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }

    private var updateFeedback: String? {
        switch store.appUpdates.updateCheckResult {
        case .upToDate:
            return "You are already on the latest app version."
        case .updateAvailable(let release):
            return "Update available: v\(release.version)."
        case .error(let error):
            return error.localizedDescription
        case nil:
            if let lastCheck = settings.lastUpdateCheck {
                return "Last checked: \(lastCheck.formatted(date: .numeric, time: .shortened))"
            }
            return nil
        }
    }
}
