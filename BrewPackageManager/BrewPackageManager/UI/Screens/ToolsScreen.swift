//
//  ToolsScreen.swift
//  BrewPackageManager
//
//  Rejilla de herramientas del popover. En el modo ventana estas entradas
//  viven en la barra lateral, así que esta pantalla solo se usa en el popover.
//

import SwiftUI

struct ToolsScreen: View {
    @Environment(NavigationModel.self) private var navigation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                SectionHeader(title: "Tools", detail: "Heavier management surfaces, grouped together.")
                LazyVGrid(columns: AppTheme.twoColumnGrid, spacing: 8) {
                    ActionTile(title: "Services", subtitle: "Control daemons", systemImage: "gearshape.2", tint: .blue) {
                        navigation.navigate(to: .services)
                    }
                    ActionTile(title: "Cleanup", subtitle: "Cache and old versions", systemImage: "trash", tint: AppTheme.statusPending) {
                        navigation.navigate(to: .cleanup)
                    }
                    ActionTile(title: "Dependencies", subtitle: "Impact before uninstalling", systemImage: "point.3.connected.trianglepath.dotted", tint: .purple) {
                        navigation.navigate(to: .dependencies)
                    }
                    ActionTile(title: "Activity", subtitle: "History of operations", systemImage: "clock.arrow.circlepath", tint: .pink) {
                        navigation.navigate(to: .history)
                    }
                    ActionTile(title: "Statistics", subtitle: "Usage and trends", systemImage: "chart.bar.xaxis", tint: AppTheme.statusPositive) {
                        navigation.navigate(to: .statistics)
                    }
                    ActionTile(title: "Hidden items", subtitle: "Restore hidden packages", systemImage: "eye.slash", tint: .teal) {
                        navigation.navigate(to: .hiddenItems)
                    }
                    ActionTile(title: "Help", subtitle: "Docs, releases and support", systemImage: "questionmark.circle", tint: .indigo) {
                        navigation.navigate(to: .help)
                    }
                }
            }
            .padding(AppTheme.pagePadding)
        }
    }
}
