//
//  DestinationScreen.swift
//  BrewPackageManager
//
//  Mapa único de destino de navegación a pantalla. Lo comparten el popover
//  y la ventana para que ambos resuelvan la pila de la misma forma.
//

import SwiftUI

struct DestinationScreen: View {
    let destination: NavigationModel.Destination

    var body: some View {
        switch destination {
        case .services: ServicesScreen()
        case .cleanup: CleanupScreen()
        case .dependencies: DependenciesScreen()
        case .history: HistoryScreen()
        case .statistics: StatisticsScreen()
        case .hiddenItems: HiddenItemsScreen()
        case .help: HelpScreen()
        case .packageDetail(let info): PackageDetailScreen(info: info)
        }
    }
}
