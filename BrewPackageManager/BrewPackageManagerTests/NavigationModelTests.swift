//
//  NavigationModelTests.swift
//  BrewPackageManagerTests
//
//  Tests del modelo de navegación de la interfaz nativa.
//

import Testing
@testable import BrewPackageManager

@MainActor
struct NavigationModelTests {

    @Test("Arranca en la pestaña de resumen con la pila vacía")
    func initialState() {
        let navigation = NavigationModel(surface: .popover)
        #expect(navigation.selectedTab == .overview)
        #expect(navigation.path.isEmpty)
        #expect(navigation.surface == .popover)
    }

    @Test("navigate apila destinos y goBack los desapila en orden")
    func pushAndPop() {
        let navigation = NavigationModel(surface: .popover)
        navigation.navigate(to: .services)
        navigation.navigate(to: .cleanup)
        #expect(navigation.path == [.services, .cleanup])
        navigation.goBack()
        #expect(navigation.path == [.services])
    }

    @Test("goBack con la pila vacía no hace nada")
    func popOnEmptyPathIsNoOp() {
        let navigation = NavigationModel(surface: .popover)
        navigation.goBack()
        #expect(navigation.path.isEmpty)
    }

    @Test("Cambiar de pestaña limpia la pila de destinos")
    func selectingTabResetsPath() {
        let navigation = NavigationModel(surface: .popover)
        navigation.navigate(to: .history)
        navigation.select(tab: .search)
        #expect(navigation.selectedTab == .search)
        #expect(navigation.path.isEmpty)
    }

    @Test("popToRoot vacía la pila sin cambiar de pestaña")
    func popToRootClearsPath() {
        let navigation = NavigationModel(surface: .window)
        navigation.select(tab: .tools)
        navigation.navigate(to: .statistics)
        navigation.navigate(to: .help)
        navigation.popToRoot()
        #expect(navigation.selectedTab == .tools)
        #expect(navigation.path.isEmpty)
    }

    @Test("Los destinos simples son iguales entre sí y distintos entre casos")
    func destinationEquality() {
        #expect(NavigationModel.Destination.services == .services)
        #expect(NavigationModel.Destination.services != .cleanup)
    }
}
