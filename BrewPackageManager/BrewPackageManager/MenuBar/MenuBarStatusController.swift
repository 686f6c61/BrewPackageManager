//
//  MenuBarStatusController.swift
//  BrewPackageManager
//
//  Created by Codex during the 1.9.0 rethinking pass.
//

import AppKit
import Observation
import SwiftUI

/// App delegate that installs the custom menu bar item once the app finishes launching.
@MainActor
final class BrewPackageManagerAppDelegate: NSObject, NSApplicationDelegate {

    private var packagesStore: PackagesStore?
    private var appSettings: AppSettings?
    private var statusController: MenuBarStatusController?

    func configure(packagesStore: PackagesStore, appSettings: AppSettings) {
        self.packagesStore = packagesStore
        self.appSettings = appSettings
        installStatusControllerIfPossible()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusControllerIfPossible()
    }

    private func installStatusControllerIfPossible() {
        guard statusController == nil,
              let packagesStore,
              let appSettings else {
            return
        }

        statusController = MenuBarStatusController(
            packagesStore: packagesStore,
            appSettings: appSettings
        )
    }
}

/// Owns the status item, popover, and quick actions menu for the menu bar app.
@MainActor
final class MenuBarStatusController: NSObject {

    private let packagesStore: PackagesStore
    private let appSettings: AppSettings
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let hostingController: MenuBarPopoverHostingController
    private var mainWindowController: NSWindowController?

    init(packagesStore: PackagesStore, appSettings: AppSettings) {
        self.packagesStore = packagesStore
        self.appSettings = appSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        self.hostingController = MenuBarPopoverHostingController(
            rootView: AnyView(
                RebootMenuRootView(presentation: .popover)
                    .environment(packagesStore)
                    .environment(appSettings)
            )
        )

        super.init()

        hostingController.onContentSizeDidChange = { [weak self] size in
            guard let self, self.popover.isShown else { return }
            self.popover.contentSize = size
        }

        configurePopover()
        configureStatusItem()
        updateStatusItemAppearance()
        observeStatusItemState()
        startBackgroundWork()

        if ProcessInfo.processInfo.environment["BPM_OPEN_MAIN_WINDOW_ON_LAUNCH"] == "1" {
            showMainWindow()
        }
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hostingController
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(handleStatusItemAction(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
        button.appearsDisabled = false
    }

    private func startBackgroundWork() {
        packagesStore.configureAutoRefresh(
            intervalSeconds: appSettings.autoRefreshInterval,
            debugMode: appSettings.debugMode
        )

        guard appSettings.checkForUpdatesEnabled,
              UpdateChecker.shouldCheckForUpdates(lastCheck: appSettings.lastUpdateCheck) else {
            return
        }

        Task {
            await packagesStore.checkForUpdates(settings: appSettings, manual: false)
        }
    }

    private func observeStatusItemState() {
        withObservationTracking {
            _ = packagesStore.isBrewAvailable
            _ = packagesStore.isRefreshing
            _ = packagesStore.isUpgradingSelected
            _ = packagesStore.visibleOutdatedCount
            _ = packagesStore.isCheckingForUpdates
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateStatusItemAppearance()
                self?.observeStatusItemState()
            }
        }
    }

    private func updateStatusItemAppearance() {
        guard let button = statusItem.button else { return }

        let iconName = iconNameForCurrentState()
        button.image = NSImage(
            systemSymbolName: iconName,
            accessibilityDescription: "Brew Package Manager"
        )
        button.image?.isTemplate = true
        button.toolTip = tooltipForCurrentState()
    }

    private func iconNameForCurrentState() -> String {
        if !packagesStore.isBrewAvailable {
            return "cube.box.fill"
        }

        if packagesStore.isRefreshing {
            return "arrow.triangle.2.circlepath"
        }

        if packagesStore.isUpgradingSelected {
            return "arrow.up.circle.fill"
        }

        if packagesStore.visibleOutdatedCount > 0 {
            return "cube.box"
        }

        return "cube.box.fill"
    }

    private func tooltipForCurrentState() -> String {
        if !packagesStore.isBrewAvailable {
            return "Brew Package Manager: Homebrew not available"
        }

        if packagesStore.isRefreshing {
            return "Brew Package Manager: Refreshing packages"
        }

        if packagesStore.isUpgradingSelected {
            return "Brew Package Manager: Updating packages"
        }

        let outdatedCount = packagesStore.visibleOutdatedCount
        if outdatedCount == 0 {
            return "Brew Package Manager: All packages up to date"
        }

        let packageWord = outdatedCount == 1 ? "package" : "packages"
        return "Brew Package Manager: \(outdatedCount) \(packageWord) need attention"
    }

    @objc private func handleStatusItemAction(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        let isSecondaryClick = event.type == .rightMouseUp
            || (event.type == .leftMouseUp && event.modifierFlags.contains(.control))

        if isSecondaryClick {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }

        popover.contentSize = hostingController.popoverContentSize
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showContextMenu() {
        popover.performClose(nil)
        statusItem.popUpMenu(makeContextMenu())
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()

        let openItem = NSMenuItem(
            title: "Open Window",
            action: #selector(openMainWindowFromMenu),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        let openMenuItem = NSMenuItem(
            title: "Open Menu",
            action: #selector(openPopoverFromMenu),
            keyEquivalent: ""
        )
        openMenuItem.target = self
        menu.addItem(openMenuItem)

        menu.addItem(.separator())

        let refreshItem = NSMenuItem(
            title: packagesStore.isRefreshing ? "Refreshing Packages…" : "Refresh Packages",
            action: #selector(refreshPackagesFromMenu),
            keyEquivalent: ""
        )
        refreshItem.target = self
        refreshItem.isEnabled = !packagesStore.isRefreshing
        menu.addItem(refreshItem)

        let visibleOutdatedCount = packagesStore.visibleOutdatedCount
        let updateTitle: String
        if visibleOutdatedCount == 0 {
            updateTitle = "No Package Updates Available"
        } else if visibleOutdatedCount == 1 {
            updateTitle = "Update 1 Visible Package"
        } else {
            updateTitle = "Update \(visibleOutdatedCount) Visible Packages"
        }

        let updateItem = NSMenuItem(
            title: updateTitle,
            action: #selector(updateVisiblePackagesFromMenu),
            keyEquivalent: ""
        )
        updateItem.target = self
        updateItem.isEnabled = visibleOutdatedCount > 0 && !packagesStore.isRefreshing && !packagesStore.isUpgradingSelected
        menu.addItem(updateItem)

        let appUpdateItem = NSMenuItem(
            title: packagesStore.isCheckingForUpdates ? "Checking for App Updates…" : "Check for App Updates",
            action: #selector(checkForAppUpdatesFromMenu),
            keyEquivalent: ""
        )
        appUpdateItem.target = self
        appUpdateItem.isEnabled = !packagesStore.isCheckingForUpdates
        menu.addItem(appUpdateItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Brew Package Manager",
            action: #selector(quitFromMenu),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func openPopoverFromMenu() {
        showPopover()
    }

    @objc private func openMainWindowFromMenu() {
        showMainWindow()
    }

    @objc private func refreshPackagesFromMenu() {
        Task {
            await packagesStore.refresh(debugMode: appSettings.debugMode, force: true)
        }
    }

    @objc private func updateVisiblePackagesFromMenu() {
        Task {
            packagesStore.selectAllOutdated()
            guard !packagesStore.selectedPackageIDs.isEmpty else { return }
            await packagesStore.upgradeSelected(debugMode: appSettings.debugMode)
        }
    }

    @objc private func checkForAppUpdatesFromMenu() {
        Task {
            await packagesStore.checkForUpdates(settings: appSettings, manual: true)
        }
    }

    @objc private func quitFromMenu() {
        AppKitBridge.quit()
    }

    private func showMainWindow() {
        let controller = makeMainWindowControllerIfNeeded()
        controller.showWindow(nil)

        if let window = controller.window {
            positionMainWindow(window)
            window.makeKeyAndOrderFront(nil)

            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window else { return }
                self.positionMainWindow(window)
                window.makeKeyAndOrderFront(nil)
            }
        }

        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    private func makeMainWindowControllerIfNeeded() -> NSWindowController {
        if let mainWindowController {
            return mainWindowController
        }

        let rootView = AnyView(
            RebootMenuRootView(presentation: .window)
                .environment(packagesStore)
                .environment(appSettings)
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Brew Package Manager"
        window.setContentSize(NSSize(width: 460, height: 720))
        window.minSize = NSSize(width: 440, height: 620)
        window.styleMask.insert(.resizable)
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        mainWindowController = controller
        return controller
    }

    private func positionMainWindow(_ window: NSWindow) {
        guard let button = statusItem.button,
              let buttonWindow = button.window else {
            window.center()
            return
        }

        let buttonFrame = buttonWindow.frame
        let screenFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let windowSize = window.frame.size

        var originX = buttonFrame.midX - (windowSize.width / 2)
        var originY = buttonFrame.minY - windowSize.height - 8

        let horizontalPadding: CGFloat = 12
        let verticalPadding: CGFloat = 12

        originX = min(
            max(originX, screenFrame.minX + horizontalPadding),
            screenFrame.maxX - windowSize.width - horizontalPadding
        )
        originY = max(originY, screenFrame.minY + verticalPadding)

        window.setFrameOrigin(NSPoint(x: originX, y: originY))
    }
}

/// Hosting controller that keeps the popover sized to the current SwiftUI content.
@MainActor
final class MenuBarPopoverHostingController: NSHostingController<AnyView> {

    var onContentSizeDidChange: ((NSSize) -> Void)?

    var popoverContentSize: NSSize {
        let fittingSize = view.fittingSize
        let insets = view.safeAreaInsets

        return NSSize(
            width: ceil(fittingSize.width + insets.left + insets.right),
            height: ceil(fittingSize.height + insets.top + insets.bottom)
        )
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        let size = popoverContentSize
        preferredContentSize = size
        onContentSizeDidChange?(size)
    }
}
