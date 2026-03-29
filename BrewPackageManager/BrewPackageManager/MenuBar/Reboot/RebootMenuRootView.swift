import AppKit
import SwiftUI

struct RebootMenuRootView: View {
    enum Presentation {
        case popover
        case window
    }

    private enum Screen: Equatable {
        case home
        case search
        case tools
        case settings
        case services
        case cleanup
        case dependencies
        case history
        case statistics
        case hiddenItems
        case help
        case packageInfo(BrewPackageInfo)
    }

    private enum PrimaryTab: String, CaseIterable, Identifiable {
        case home = "Overview"
        case search = "Search"
        case tools = "Tools"
        case settings = "Settings"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .home: return "sparkles.rectangle.stack"
            case .search: return "magnifyingglass"
            case .tools: return "square.grid.2x2"
            case .settings: return "slider.horizontal.3"
            }
        }

        var screen: Screen {
            switch self {
            case .home: return .home
            case .search: return .search
            case .tools: return .tools
            case .settings: return .settings
            }
        }
    }

    @Environment(PackagesStore.self) private var store
    @Environment(AppSettings.self) private var settings

    private let presentation: Presentation

    @State private var screen: Screen = .home
    @State private var previousScreen: Screen = .home

    init(presentation: Presentation = .popover) {
        self.presentation = presentation
    }

    var body: some View {
        VStack(spacing: 0) {
            chrome
            Divider().overlay(RebootTheme.outline)
            currentScreenView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(RebootTheme.canvas)
        .frame(
            width: presentation == .popover ? RebootTheme.popoverWidth : nil,
            height: presentation == .popover ? RebootTheme.popoverHeight : nil
        )
        .frame(
            minWidth: presentation == .window ? RebootTheme.windowMinWidth : nil,
            minHeight: presentation == .window ? RebootTheme.windowMinHeight : nil
        )
        .alert("Warning", isPresented: Binding(
            get: { store.nonFatalError != nil },
            set: { if !$0 { store.dismissError() } }
        )) {
            Button("OK") { store.dismissError() }
        } message: {
            if let error = store.nonFatalError {
                Text(error.localizedDescription)
            }
        }
    }

    private var chrome: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                if isPrimaryScreen {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Brew Package Manager")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(primarySubtitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(RebootTheme.subduedText)
                    }
                } else {
                    Button(action: goBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(RebootTheme.elevatedStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(detailTitle)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(detailSubtitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(RebootTheme.subduedText)
                    }
                }

                Spacer(minLength: 12)

                if isPrimaryScreen {
                    HStack(spacing: 10) {
                        RebootTag(text: updateTagText, tint: store.visibleOutdatedCount == 0 ? RebootTheme.positive : RebootTheme.accent)
                        RebootGhostButton(
                            title: store.isRefreshing ? "Refreshing" : "Refresh",
                            systemImage: store.isRefreshing ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.clockwise",
                            isDisabled: store.isRefreshing,
                            action: refreshPackages
                        )
                    }
                } else {
                    RebootGhostButton(title: "Home", systemImage: "house", action: { show(.home) })
                }
            }

            if isPrimaryScreen {
                HStack(spacing: 8) {
                    ForEach(PrimaryTab.allCases) { tab in
                        Button(action: { show(tab.screen) }) {
                            HStack(spacing: 8) {
                                Image(systemName: tab.systemImage)
                                    .font(.system(size: 12, weight: .bold))
                                Text(tab.rawValue)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(selectedPrimaryTab == tab ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                Group {
                                    if selectedPrimaryTab == tab {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.white)
                                    } else {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(RebootTheme.elevatedStrong)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, RebootTheme.pageHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private var currentScreenView: some View {
        switch screen {
        case .home:
            RebootHomeScreen(
                openSearch: { show(.search) },
                openTools: { show(.tools) },
                openSettings: { show(.settings) },
                openServices: { push(.services) },
                openCleanup: { push(.cleanup) },
                showPackageInfo: showPackageInfo(for:),
                refresh: refreshPackages,
                updateAllVisible: updateAllVisible
            )
        case .search:
            RebootSearchScreen(showPackageInfo: showSearchResultInfo(for:))
        case .tools:
            RebootToolsScreen(
                openServices: { push(.services) },
                openCleanup: { push(.cleanup) },
                openDependencies: { push(.dependencies) },
                openHistory: { push(.history) },
                openStatistics: { push(.statistics) },
                openHiddenItems: { push(.hiddenItems) },
                openHelp: { push(.help) }
            )
        case .settings:
            RebootSettingsScreen()
        case .services:
            RebootServicesScreen()
        case .cleanup:
            RebootCleanupScreen()
        case .dependencies:
            RebootDependenciesScreen()
        case .history:
            RebootHistoryScreen()
        case .statistics:
            RebootStatisticsScreen()
        case .hiddenItems:
            RebootHiddenItemsScreen()
        case .help:
            RebootHelpScreen()
        case .packageInfo(let info):
            RebootPackageInfoScreen(info: info)
        }
    }

    private var isPrimaryScreen: Bool {
        switch screen {
        case .home, .search, .tools, .settings:
            return true
        default:
            return false
        }
    }

    private var selectedPrimaryTab: PrimaryTab {
        switch screen {
        case .home: return .home
        case .search: return .search
        case .tools: return .tools
        case .settings: return .settings
        default: return .home
        }
    }

    private var primarySubtitle: String {
        if store.visibleOutdatedCount == 0 {
            return "Everything important is calm right now."
        }

        let packageWord = store.visibleOutdatedCount == 1 ? "package" : "packages"
        return "\(store.visibleOutdatedCount) visible \(packageWord) need attention."
    }

    private var updateTagText: String {
        if store.visibleOutdatedCount == 0 {
            return "All good"
        }
        return "\(store.visibleOutdatedCount) updates"
    }

    private var detailTitle: String {
        switch screen {
        case .services: return "Services"
        case .cleanup: return "Cleanup"
        case .dependencies: return "Dependencies"
        case .history: return "Activity"
        case .statistics: return "Statistics"
        case .hiddenItems: return "Hidden Items"
        case .help: return "Help"
        case .packageInfo(let info): return info.name
        default: return ""
        }
    }

    private var detailSubtitle: String {
        switch screen {
        case .services:
            return "Control daemons and see live status."
        case .cleanup:
            return "Manage cache and removable package versions."
        case .dependencies:
            return "Understand package relationships before changing anything."
        case .history:
            return "Review operations and errors over time."
        case .statistics:
            return "A condensed view of usage trends."
        case .hiddenItems:
            return "Restore anything you decided to hide."
        case .help:
            return "Support, docs and release links."
        case .packageInfo(let info):
            return info.fullName
        default:
            return ""
        }
    }

    private func show(_ next: Screen) {
        screen = next
    }

    private func push(_ next: Screen) {
        previousScreen = screen
        screen = next
    }

    private func goBack() {
        screen = previousScreen
    }

    private func refreshPackages() {
        Task {
            await store.refresh(debugMode: settings.debugMode, force: true)
        }
    }

    private func updateAllVisible() {
        Task {
            store.selectAllOutdated()
            guard !store.selectedPackageIDs.isEmpty else { return }
            await store.upgradeSelected(debugMode: settings.debugMode)
        }
    }

    private func showPackageInfo(for package: BrewPackage) {
        previousScreen = screen
        Task {
            await store.fetchPackageInfo(package.name, type: package.type, debugMode: settings.debugMode)
            if let info = store.selectedPackageInfo {
                screen = .packageInfo(info)
            }
        }
    }

    private func showSearchResultInfo(for result: SearchResult) {
        previousScreen = screen
        Task {
            await store.fetchSearchResultInfo(result, debugMode: settings.debugMode)
            if let updated = store.searchResults.first(where: { $0.id == result.id }),
               let info = updated.info {
                screen = .packageInfo(info)
            }
        }
    }
}

private struct RebootHomeScreen: View {
    @Environment(PackagesStore.self) private var store
    @State private var inventoryLimit = 6

    let openSearch: () -> Void
    let openTools: () -> Void
    let openSettings: () -> Void
    let openServices: () -> Void
    let openCleanup: () -> Void
    let showPackageInfo: (BrewPackage) -> Void
    let refresh: () -> Void
    let updateAllVisible: () -> Void

    private var trackedPackages: [BrewPackage] {
        Array(store.visiblePackages.prefix(inventoryLimit))
    }

    private var attentionPackages: [BrewPackage] {
        Array(store.visibleOutdatedPackages.prefix(6))
    }

    private var canShowMoreInventory: Bool {
        trackedPackages.count < store.visiblePackages.count
    }

    private var canShowLessInventory: Bool {
        inventoryLimit > 6 && !store.visiblePackages.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RebootTheme.pageVerticalSpacing) {
                heroCard
                quickActions
                updatesBlock
                inventoryBlock
            }
            .padding(.horizontal, RebootTheme.pageHorizontalPadding)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.never)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            RebootSectionHeader(
                eyebrow: "System overview",
                title: store.visibleOutdatedCount == 0 ? "No visible fires right now" : "Your packages need a decision",
                detail: store.visibleOutdatedCount == 0 ? "Pinned and hidden updates stay out of the way, but nothing actionable is pending." : "Use one clean action for the bulk update, then review edge cases from below."
            )

            HStack(spacing: 10) {
                RebootMetricPill(title: "Actionable updates", value: "\(store.visibleOutdatedCount)", tint: store.visibleOutdatedCount == 0 ? RebootTheme.positive : RebootTheme.accent)
                RebootMetricPill(title: "Installed", value: "\(store.visiblePackages.count)", tint: RebootTheme.secondaryAccent)
                RebootMetricPill(title: "Hidden", value: "\(store.hiddenItems.count)", tint: RebootTheme.warning)
            }

            HStack(spacing: 10) {
                RebootActionButton(
                    title: store.visibleOutdatedCount == 0 ? "Refresh inventory" : "Update all visible",
                    systemImage: store.visibleOutdatedCount == 0 ? "arrow.clockwise" : "arrow.up.circle.fill",
                    tint: store.visibleOutdatedCount == 0 ? RebootTheme.secondaryAccent : RebootTheme.accent,
                    isBusy: false,
                    isDisabled: store.visibleOutdatedCount == 0 ? false : store.selectedPackageIDs.isEmpty && store.visibleOutdatedCount == 0,
                    action: store.visibleOutdatedCount == 0 ? refresh : updateAllVisible
                )

                RebootGhostButton(title: "Search packages", systemImage: "magnifyingglass", action: openSearch)
                RebootGhostButton(title: "Settings", systemImage: "slider.horizontal.3", action: openSettings)
            }
        }
        .rebootCard()
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            RebootSectionHeader(eyebrow: "Jump in", title: "Start from the action, not from a maze", detail: nil)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                RebootTileButton(title: "Services", subtitle: "Manage running daemons", systemImage: "gearshape.2", tint: RebootTheme.secondaryAccent, action: openServices)
                RebootTileButton(title: "Cleanup", subtitle: "Cache and old versions", systemImage: "trash.slash", tint: RebootTheme.warning, action: openCleanup)
                RebootTileButton(title: "All tools", subtitle: "Dependencies, history and more", systemImage: "square.grid.2x2", tint: Color.pink, action: openTools)
                RebootTileButton(title: "Refresh", subtitle: "Sync the latest Homebrew state", systemImage: "arrow.clockwise", tint: RebootTheme.positive, action: refresh)
            }
        }
    }

    private var updatesBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            RebootSectionHeader(
                eyebrow: "Attention",
                title: attentionPackages.isEmpty ? "Nothing actionable to update" : "Packages needing your eyes",
                detail: attentionPackages.isEmpty ? "Pinned and hidden updates stay excluded from this list." : "This list is intentionally short and clean: only user-visible updates live here."
            )

            if attentionPackages.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Everything visible is already aligned.")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("If something still bothers you, check hidden items or pinned packages from Tools.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(RebootTheme.subduedText)
                }
                .rebootCard()
            } else {
                VStack(spacing: 10) {
                    ForEach(attentionPackages) { package in
                        RebootPackageRow(
                            package: package,
                            actionTitle: "Details",
                            primaryAction: { showPackageInfo(package) },
                            secondaryAction: { store.hideUpdate(for: package) },
                            secondaryTitle: "Hide"
                        )
                    }
                }
            }
        }
    }

    private var inventoryBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            RebootSectionHeader(eyebrow: "Installed", title: "A quick inventory snapshot", detail: "A lighter glance at what is installed, without burying the popover in rows.")

            VStack(spacing: 10) {
                ForEach(trackedPackages) { package in
                    RebootInventoryRow(package: package) {
                        showPackageInfo(package)
                    }
                }
            }

            if canShowMoreInventory || canShowLessInventory {
                HStack(spacing: 10) {
                    if canShowMoreInventory {
                        RebootGhostButton(
                            title: "Show more (\(min(inventoryLimit + 6, store.visiblePackages.count)))",
                            systemImage: "chevron.down"
                        ) {
                            inventoryLimit = min(inventoryLimit + 6, store.visiblePackages.count)
                        }
                    }

                    if canShowLessInventory {
                        RebootGhostButton(title: "Show less", systemImage: "chevron.up") {
                            inventoryLimit = 6
                        }
                    }
                }
            }
        }
    }
}

private struct RebootSearchScreen: View {
    @Environment(PackagesStore.self) private var store
    @Environment(AppSettings.self) private var settings

    let showPackageInfo: (SearchResult) -> Void

    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RebootTheme.pageVerticalSpacing) {
                searchIntro
                searchControls
                searchResults
            }
            .padding(.horizontal, RebootTheme.pageHorizontalPadding)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.never)
        .onDisappear {
            searchTask?.cancel()
            searchTask = nil
        }
    }

    private var searchIntro: some View {
        RebootSectionHeader(
            eyebrow: "Search",
            title: "Find packages without leaving the flow",
            detail: "This is live search with a cleaner result card layout and direct install feedback."
        )
    }

    private var searchControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(RebootTheme.subduedText)
                TextField("Search formulae or casks", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, newValue in
                        scheduleSearch(for: newValue)
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(RebootTheme.elevatedStrong, in: RoundedRectangle(cornerRadius: RebootTheme.cardCornerRadius, style: .continuous))

            HStack(spacing: 8) {
                filterButton(label: "All", value: nil)
                filterButton(label: "Formulae", value: .formula)
                filterButton(label: "Casks", value: .cask)
            }
        }
        .rebootCard()
    }

    @ViewBuilder
    private var searchResults: some View {
        switch store.searchState {
        case .idle:
            VStack(alignment: .leading, spacing: 10) {
                Text("Start typing to search Homebrew.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Results show install state, type and direct access to details.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(RebootTheme.subduedText)
            }
            .rebootCard()
        case .searching(let query):
            VStack(alignment: .leading, spacing: 10) {
                ProgressView()
                Text("Searching for \(query)…")
                    .foregroundStyle(.white)
            }
            .rebootCard()
        case .loaded(_, let results, let hasMore):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(results) { result in
                    RebootSearchResultRow(result: result, operation: store.installOperations[result.name]) {
                        Task { await store.installPackage(result, debugMode: settings.debugMode) }
                    } detailsAction: {
                        showPackageInfo(result)
                    }
                }

                if hasMore {
                    Text("Refine the query to narrow down more results.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(RebootTheme.subduedText)
                        .padding(.horizontal, 4)
                }
            }
        case .error(let error):
            VStack(alignment: .leading, spacing: 10) {
                Text("Search failed")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(error.localizedDescription)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(RebootTheme.subduedText)
            }
            .rebootCard()
        }
    }

    private func filterButton(label: String, value: PackageType?) -> some View {
        let selected = store.searchTypeFilter == value
        return Button {
            store.searchTypeFilter = value
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                scheduleSearch(for: searchText, immediately: true)
            }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(selected ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(selected ? Color.white : RebootTheme.elevatedStrong, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func scheduleSearch(for query: String, immediately: Bool = false) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            store.clearSearch(resetFilter: false)
            return
        }

        searchTask = Task {
            if !immediately {
                try? await Task.sleep(for: .milliseconds(350))
            }
            guard !Task.isCancelled else { return }
            await store.search(query: trimmed, debugMode: settings.debugMode)
        }
    }
}

private struct RebootToolsScreen: View {
    @Environment(PackagesStore.self) private var store

    let openServices: () -> Void
    let openCleanup: () -> Void
    let openDependencies: () -> Void
    let openHistory: () -> Void
    let openStatistics: () -> Void
    let openHiddenItems: () -> Void
    let openHelp: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RebootTheme.pageVerticalSpacing) {
                RebootSectionHeader(
                    eyebrow: "Toolbox",
                    title: "Deep work lives here",
                    detail: "All the heavier management surfaces are grouped together instead of being mixed into the main package stream."
                )

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                    RebootTileButton(title: "Services", subtitle: "\(store.visiblePackages.count) packages tracked", systemImage: "gearshape.2.fill", tint: RebootTheme.secondaryAccent, action: openServices)
                    RebootTileButton(title: "Cleanup", subtitle: "Cache and old versions", systemImage: "trash.fill", tint: RebootTheme.warning, action: openCleanup)
                    RebootTileButton(title: "Dependencies", subtitle: "Map impact before uninstalling", systemImage: "point.3.connected.trianglepath.dotted", tint: .purple, action: openDependencies)
                    RebootTileButton(title: "Activity", subtitle: "History of operations", systemImage: "clock.arrow.circlepath", tint: .pink, action: openHistory)
                    RebootTileButton(title: "Statistics", subtitle: "Usage and trends", systemImage: "chart.bar.xaxis", tint: RebootTheme.positive, action: openStatistics)
                    RebootTileButton(title: "Hidden Items", subtitle: "Restore hidden packages or updates", systemImage: "eye.slash.fill", tint: .teal, action: openHiddenItems)
                    RebootTileButton(title: "Help", subtitle: "Docs, releases and support", systemImage: "questionmark.circle.fill", tint: .indigo, action: openHelp)
                }
            }
            .padding(.horizontal, RebootTheme.pageHorizontalPadding)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.never)
    }
}

private struct RebootSettingsScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PackagesStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RebootTheme.pageVerticalSpacing) {
                RebootSectionHeader(
                    eyebrow: "Settings",
                    title: "Tune the app without modal clutter",
                    detail: "Critical toggles, refresh behavior and app update checks are all visible at once."
                )

                VStack(alignment: .leading, spacing: 12) {
                    RebootToggleRow(title: "Launch at login", subtitle: "Start Brew Package Manager with macOS", isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.launchAtLogin = $0 }
                    ))
                    RebootToggleRow(title: "Automatic app update checks", subtitle: "Periodically look for GitHub releases", isOn: Binding(
                        get: { settings.checkForUpdatesEnabled },
                        set: { settings.checkForUpdatesEnabled = $0 }
                    ))
                    RebootToggleRow(title: "Show only outdated packages", subtitle: "Keep the home inventory focused", isOn: Binding(
                        get: { settings.onlyShowOutdated },
                        set: { settings.onlyShowOutdated = $0 }
                    ))
                    RebootToggleRow(title: "Debug mode", subtitle: "Verbose diagnostics for Homebrew commands", isOn: Binding(
                        get: { settings.debugMode },
                        set: { settings.debugMode = $0 }
                    ))
                }
                .rebootCard()

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Auto-refresh interval")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Set to 0 to disable automatic refreshes.")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(RebootTheme.subduedText)
                        }
                        Spacer()
                        TextField("Seconds", value: Binding(
                            get: { settings.autoRefreshInterval },
                            set: { settings.autoRefreshInterval = $0 }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 88)
                    }

                    RebootActionButton(
                        title: store.isCheckingForUpdates ? "Checking for updates" : "Check for app updates now",
                        systemImage: "arrow.clockwise",
                        tint: RebootTheme.secondaryAccent,
                        isBusy: store.isCheckingForUpdates,
                        isDisabled: store.isCheckingForUpdates
                    ) {
                        Task { await store.checkForUpdates(settings: settings, manual: true) }
                    }

                    if let feedback = updateFeedback {
                        Text(feedback)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(RebootTheme.subduedText)
                    }
                }
                .rebootCard()
            }
            .padding(.horizontal, RebootTheme.pageHorizontalPadding)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.never)
    }

    private var updateFeedback: String? {
        switch store.updateCheckResult {
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

private struct RebootServicesScreen: View {
    @State private var store = ServicesStore()
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RebootTheme.pageVerticalSpacing) {
                VStack(alignment: .leading, spacing: 14) {
                    RebootSectionHeader(eyebrow: "Runtime", title: "Service health at a glance", detail: "Each row only shows the actions that make sense for its current state.")

                    HStack(spacing: 10) {
                        RebootMetricPill(title: "Running", value: "\(store.runningCount)", tint: RebootTheme.positive)
                        RebootMetricPill(title: "Stopped", value: "\(store.stoppedCount)", tint: RebootTheme.warning)
                    }

                    RebootActionButton(
                        title: store.isRefreshing ? "Refreshing services" : "Refresh services",
                        systemImage: "arrow.clockwise",
                        tint: RebootTheme.secondaryAccent,
                        isBusy: store.isRefreshing,
                        isDisabled: store.isRefreshing
                    ) {
                        loadTask?.cancel()
                        loadTask = Task { await store.fetchServices(showStatusMessage: true) }
                    }
                }
                .rebootCard()

                if let statusMessage = store.statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(RebootTheme.subduedText)
                        .rebootCard()
                }

                VStack(spacing: 10) {
                    ForEach(store.services) { service in
                        RebootServiceRow(
                            service: service,
                            operationState: store.operationState(for: service.id),
                            onStart: { await store.startService(service) },
                            onStop: { await store.stopService(service) },
                            onRestart: { await store.restartService(service) }
                        )
                    }
                }
            }
            .padding(.horizontal, RebootTheme.pageHorizontalPadding)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.never)
        .task {
            guard store.services.isEmpty, !store.isLoading else { return }
            loadTask?.cancel()
            loadTask = Task { await store.fetchServices(showStatusMessage: true) }
        }
        .onDisappear {
            loadTask?.cancel()
        }
        .alert("Error", isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )) {
            Button("OK") { store.lastError = nil }
        } message: {
            if let error = store.lastError {
                Text(error.localizedDescription)
            }
        }
    }
}

private struct RebootCleanupScreen: View {
    @State private var store = CleanupStore()
    @State private var loadTask: Task<Void, Never>?
    @State private var showCleanupConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RebootTheme.pageVerticalSpacing) {
                RebootSectionHeader(
                    eyebrow: "Storage",
                    title: "Make cleanup decisions with context",
                    detail: "Cache and removable versions are separated clearly so one action never pretends to do the other."
                )

                HStack(spacing: 10) {
                    RebootMetricPill(title: "Cache", value: store.cleanupInfo.cacheSizeFormatted, tint: RebootTheme.secondaryAccent)
                    RebootMetricPill(title: "Old versions", value: "\(store.cleanupInfo.oldVersions)", tint: RebootTheme.warning)
                }

                VStack(alignment: .leading, spacing: 12) {
                    RebootActionButton(
                        title: "Clear download cache",
                        systemImage: "xmark.bin.fill",
                        tint: RebootTheme.secondaryAccent,
                        isBusy: store.isCleaning && store.cleanupInfo.cacheSize > 0,
                        isDisabled: store.isCleaning || store.cleanupInfo.cacheSize == 0
                    ) {
                        Task { await store.clearCache() }
                    }

                    RebootActionButton(
                        title: "Clean old versions",
                        systemImage: "trash.fill",
                        tint: RebootTheme.warning,
                        isBusy: store.isCleaning && store.cleanupInfo.oldVersions > 0,
                        isDisabled: store.isCleaning || store.cleanupInfo.oldVersions == 0
                    ) {
                        showCleanupConfirmation = true
                    }

                    RebootGhostButton(title: store.isLoading ? "Refreshing" : "Refresh analysis", systemImage: "arrow.clockwise", isDisabled: store.isLoading) {
                        loadTask?.cancel()
                        loadTask = Task { await store.fetchCleanupInfo() }
                    }
                }
                .rebootCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text(store.cleanupInfo.cacheExplanation)
                    Text(store.cleanupInfo.oldVersionsExplanation)
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(RebootTheme.subduedText)
                .rebootCard()

                if let result = store.lastCleanupResult {
                    Text(result)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .rebootCard()
                }
            }
            .padding(.horizontal, RebootTheme.pageHorizontalPadding)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.never)
        .task {
            guard !store.isLoading else { return }
            loadTask?.cancel()
            loadTask = Task { await store.fetchCleanupInfo() }
        }
        .onDisappear {
            loadTask?.cancel()
        }
        .alert("Clean old versions?", isPresented: $showCleanupConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clean") {
                Task { await store.performCleanup() }
            }
        } message: {
            Text("This removes only previous package versions left behind after upgrades. It does not uninstall the current version.")
        }
        .alert("Error", isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )) {
            Button("OK") { store.lastError = nil }
        } message: {
            if let error = store.lastError {
                Text(error.localizedDescription)
            }
        }
    }
}

private struct RebootDependenciesScreen: View {
    @State private var store = DependenciesStore()
    @State private var filter = ""

    private var filtered: [DependencyInfo] {
        if filter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return store.dependencies
        }
        return store.dependencies.filter { $0.packageName.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RebootTheme.pageVerticalSpacing) {
                RebootSectionHeader(
                    eyebrow: "Impact map",
                    title: "Check what depends on what",
                    detail: "This screen is about consequences before you uninstall or refactor your setup."
                )

                HStack(spacing: 10) {
                    RebootMetricPill(title: "Packages", value: "\(store.dependencies.count)", tint: RebootTheme.secondaryAccent)
                    RebootMetricPill(title: "Total deps", value: "\(store.totalDependencies)", tint: .purple)
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(RebootTheme.subduedText)
                    TextField("Filter packages", text: $filter)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(RebootTheme.elevatedStrong, in: RoundedRectangle(cornerRadius: RebootTheme.cardCornerRadius, style: .continuous))

                VStack(spacing: 10) {
                    ForEach(filtered) { dependency in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(dependency.packageName)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                RebootTag(text: "\(dependency.dependencies.count) deps", tint: .purple)
                            }

                            if dependency.dependencies.isEmpty {
                                Text("No dependencies")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(RebootTheme.subduedText)
                            } else {
                                Text(dependency.dependencies.joined(separator: ", "))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(RebootTheme.subduedText)
                            }
                        }
                        .rebootCard()
                    }
                }
            }
            .padding(.horizontal, RebootTheme.pageHorizontalPadding)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.never)
        .task {
            guard store.dependencies.isEmpty, !store.isLoading else { return }
            await store.fetchAllDependencies()
        }
        .alert("Error", isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )) {
            Button("OK") { store.lastError = nil }
        } message: {
            if let error = store.lastError {
                Text(error.localizedDescription)
            }
        }
    }
}

private struct RebootHistoryScreen: View {
    @State private var store = HistoryStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RebootTheme.pageVerticalSpacing) {
                RebootSectionHeader(
                    eyebrow: "Activity",
                    title: "A clean timeline of what happened",
                    detail: "When something breaks, this is where the narrative should stay readable."
                )

                HStack(spacing: 10) {
                    RebootMetricPill(title: "Events", value: "\(store.totalOperations)", tint: RebootTheme.secondaryAccent)
                    RebootMetricPill(title: "Success rate", value: String(format: "%.0f%%", store.successRate), tint: RebootTheme.positive)
                }

                VStack(spacing: 10) {
                    ForEach(Array(store.filteredEntries.prefix(20))) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(entry.packageName)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                RebootTag(text: entry.operation.rawValue.capitalized, tint: entry.success ? RebootTheme.positive : RebootTheme.critical)
                            }
                            Text(entry.timestamp.formatted(date: .numeric, time: .shortened))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(RebootTheme.subduedText)
                            if let details = entry.details, !details.isEmpty {
                                Text(details)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(RebootTheme.subduedText)
                            }
                        }
                        .rebootCard()
                    }
                }
            }
            .padding(.horizontal, RebootTheme.pageHorizontalPadding)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.never)
        .task {
            guard store.entries.isEmpty, !store.isLoading else { return }
            await store.loadHistory()
        }
    }
}

private struct RebootStatisticsScreen: View {
    @State private var store = HistoryStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RebootTheme.pageVerticalSpacing) {
                RebootSectionHeader(
                    eyebrow: "Statistics",
                    title: "Signal instead of spreadsheet vibes",
                    detail: "The goal is fast understanding, not dashboard cosplay."
                )

                HStack(spacing: 10) {
                    RebootMetricPill(title: "Operations", value: "\(store.totalOperations)", tint: RebootTheme.secondaryAccent)
                    RebootMetricPill(title: "Success", value: String(format: "%.0f%%", store.successRate), tint: RebootTheme.positive)
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(store.operationCounts.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { operation in
                        HStack {
                            Text(operation.rawValue.capitalized)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(store.operationCounts[operation, default: 0])")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .rebootCard()
                    }
                }
            }
            .padding(.horizontal, RebootTheme.pageHorizontalPadding)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.never)
        .task {
            guard store.entries.isEmpty, !store.isLoading else { return }
            await store.loadHistory()
        }
    }
}

private struct RebootHiddenItemsScreen: View {
    @Environment(PackagesStore.self) private var store

    private var hiddenPackages: [PackagesStore.HiddenItem] {
        store.hiddenItems.filter { $0.kind == .package }
    }

    private var hiddenUpdates: [PackagesStore.HiddenItem] {
        store.hiddenItems.filter { $0.kind == .update }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RebootTheme.pageVerticalSpacing) {
                RebootSectionHeader(
                    eyebrow: "Visibility",
                    title: "Undo any hidden choice",
                    detail: "Nothing is buried. Hidden packages and hidden updates are separated cleanly."
                )

                if hiddenPackages.isEmpty && hiddenUpdates.isEmpty {
                    Text("No hidden items right now.")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .rebootCard()
                } else {
                    if !hiddenPackages.isEmpty {
                        RebootHiddenGroup(title: "Hidden packages", items: hiddenPackages) { item in
                            store.unhidePackage(item.package.id)
                        }
                    }

                    if !hiddenUpdates.isEmpty {
                        RebootHiddenGroup(title: "Hidden updates", items: hiddenUpdates) { item in
                            store.unhideUpdate(for: item.package.id)
                        }
                    }
                }
            }
            .padding(.horizontal, RebootTheme.pageHorizontalPadding)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.never)
    }
}

private struct RebootHelpScreen: View {
    private var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "2.0.0"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RebootTheme.pageVerticalSpacing) {
                RebootSectionHeader(
                    eyebrow: "Support",
                    title: "The essentials, without the clutter",
                    detail: "Links that matter, plain language and no decorative noise."
                )

                VStack(alignment: .leading, spacing: 10) {
                    RebootInfoLine(label: "Author", value: "686f6c61")
                    RebootInfoLine(label: "Current version", value: currentVersion)
                }
                .rebootCard()

                VStack(spacing: 10) {
                    RebootLinkCard(title: "Repository", subtitle: "Open the GitHub repository", urlString: "https://github.com/686f6c61/BrewPackageManager")
                    RebootLinkCard(title: "Author", subtitle: "Open the author profile on GitHub", urlString: "https://github.com/686f6c61")
                    RebootLinkCard(title: "Changelog", subtitle: "Review everything that changed between releases", urlString: "https://github.com/686f6c61/BrewPackageManager/blob/main/CHANGELOG.md")
                    RebootLinkCard(title: "Releases", subtitle: "Check the latest DMG and release notes", urlString: "https://github.com/686f6c61/BrewPackageManager/releases")
                    RebootLinkCard(title: "Homebrew", subtitle: "Official Homebrew documentation", urlString: "https://brew.sh")
                }
            }
            .padding(.horizontal, RebootTheme.pageHorizontalPadding)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.never)
    }
}

private struct RebootPackageInfoScreen: View {
    let info: BrewPackageInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RebootTheme.pageVerticalSpacing) {
                VStack(alignment: .leading, spacing: 14) {
                    RebootSectionHeader(
                        eyebrow: "Package detail",
                        title: info.name,
                        detail: info.fullName
                    )

                    if let description = info.desc {
                        Text(description)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    HStack(spacing: 10) {
                        RebootMetricPill(title: "Stable", value: info.versions.stable ?? "-", tint: RebootTheme.secondaryAccent)
                        RebootMetricPill(title: "Installed", value: info.installedVersions?.first?.version ?? "-", tint: RebootTheme.positive)
                    }
                }
                .rebootCard()

                VStack(alignment: .leading, spacing: 10) {
                    if let license = info.license {
                        RebootInfoLine(label: "License", value: license)
                    }
                    if let homepage = info.homepage {
                        RebootInfoLine(label: "Homepage", value: homepage)
                    }
                    if let linkedKeg = info.linkedKeg {
                        RebootInfoLine(label: "Linked keg", value: linkedKeg)
                    }
                }
                .rebootCard()

                HStack(spacing: 10) {
                    if let homepage = info.homepage, let url = URL(string: homepage) {
                        RebootGhostButton(title: "Open homepage", systemImage: "link") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    if let changelogURL = info.changelogURL {
                        RebootGhostButton(title: "Releases", systemImage: "arrow.up.right.square") {
                            NSWorkspace.shared.open(changelogURL)
                        }
                    }
                }
            }
            .padding(.horizontal, RebootTheme.pageHorizontalPadding)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.never)
    }
}

private struct RebootTileButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(RebootTheme.subduedText)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RebootTheme.elevated, in: RoundedRectangle(cornerRadius: RebootTheme.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RebootTheme.cardCornerRadius, style: .continuous)
                    .stroke(RebootTheme.outline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct RebootPackageRow: View {
    @Environment(PackagesStore.self) private var store

    let package: BrewPackage
    let actionTitle: String
    let primaryAction: () -> Void
    let secondaryAction: () -> Void
    let secondaryTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(package.displayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        RebootTag(text: package.type.label, tint: package.type == .formula ? RebootTheme.secondaryAccent : .purple)
                        if let currentVersion = package.currentVersion {
                            Text("\(package.installedVersion) -> \(currentVersion)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(RebootTheme.subduedText)
                        }
                    }
                }
                Spacer()
                Menu {
                    Button(actionTitle, action: primaryAction)
                    Button(secondaryTitle, action: secondaryAction)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
            }

            if let desc = package.desc, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(RebootTheme.subduedText)
            }
        }
        .rebootCard()
    }
}

private struct RebootInventoryRow: View {
    let package: BrewPackage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: package.type.systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(package.type == .formula ? RebootTheme.secondaryAccent : .purple)
                    .frame(width: 28, height: 28)
                    .background(RebootTheme.elevatedStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(package.displayName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(package.installedVersion)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(RebootTheme.subduedText)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(RebootTheme.subduedText)
            }
            .rebootCard()
        }
        .buttonStyle(.plain)
    }
}

private struct RebootSearchResultRow: View {
    let result: SearchResult
    let operation: PackageOperation?
    let installAction: () -> Void
    let detailsAction: () -> Void

    private var isInstalling: Bool {
        operation?.status == .running
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        RebootTag(text: result.type.label, tint: result.type == .formula ? RebootTheme.secondaryAccent : .purple)
                        if result.isInstalled {
                            RebootTag(text: "Installed", tint: RebootTheme.positive)
                        }
                    }
                }
                Spacer()
            }

            HStack(spacing: 10) {
                RebootGhostButton(title: "Details", systemImage: "info.circle", action: detailsAction)
                if !result.isInstalled {
                    RebootActionButton(
                        title: isInstalling ? "Installing" : "Install",
                        systemImage: "arrow.down.circle.fill",
                        tint: RebootTheme.accent,
                        isBusy: isInstalling,
                        isDisabled: isInstalling,
                        action: installAction
                    )
                }
            }

            if let diagnostics = operation?.diagnostics, !diagnostics.isEmpty {
                Text(diagnostics)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(RebootTheme.subduedText)
            }
        }
        .rebootCard()
    }
}

private struct RebootServiceRow: View {
    let service: BrewService
    let operationState: ServicesStore.ServiceOperationState
    let onStart: () async -> Void
    let onStop: () async -> Void
    let onRestart: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(service.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        RebootTag(text: service.status.displayText, tint: statusTint)
                        if let pid = service.pid {
                            Text("PID \(pid)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(RebootTheme.subduedText)
                        }
                    }

                    if !service.metadataSummary.isEmpty {
                        Text(service.metadataSummary)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(RebootTheme.subduedText)
                    }

                    if let operationMessage {
                        Text(operationMessage)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(operationTint)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if isRunningOperation {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        if service.status == .stopped || service.status == .error {
                            RebootIconButton(systemImage: "play.fill", tint: RebootTheme.positive) {
                                Task { await onStart() }
                            }
                        }
                        if service.status == .started {
                            RebootIconButton(systemImage: "stop.fill", tint: RebootTheme.critical) {
                                Task { await onStop() }
                            }
                            RebootIconButton(systemImage: "arrow.clockwise", tint: RebootTheme.secondaryAccent) {
                                Task { await onRestart() }
                            }
                        }
                    }
                }
            }
        }
        .rebootCard()
    }

    private var statusTint: Color {
        switch service.status {
        case .started: return RebootTheme.positive
        case .stopped: return RebootTheme.warning
        case .error: return RebootTheme.critical
        case .unknown: return .purple
        }
    }

    private var isRunningOperation: Bool {
        if case .running = operationState {
            return true
        }
        return false
    }

    private var operationMessage: String? {
        switch operationState {
        case .idle:
            return nil
        case .running(let action):
            return "\(action.displayName) \(service.name)…"
        case .succeeded(_, let message):
            return message
        case .failed(_, let error):
            return error.localizedDescription
        }
    }

    private var operationTint: Color {
        switch operationState {
        case .idle:
            return RebootTheme.subduedText
        case .running:
            return RebootTheme.secondaryAccent
        case .succeeded:
            return RebootTheme.positive
        case .failed:
            return RebootTheme.critical
        }
    }
}

private struct RebootHiddenGroup: View {
    let title: String
    let items: [PackagesStore.HiddenItem]
    let action: (PackagesStore.HiddenItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.package.displayName)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(item.kind.title)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(RebootTheme.subduedText)
                    }
                    Spacer()
                    RebootGhostButton(title: "Restore", systemImage: "eye") {
                        action(item)
                    }
                }
                .rebootCard()
            }
        }
    }
}

private struct RebootLinkCard: View {
    let title: String
    let subtitle: String
    let urlString: String

    var body: some View {
        Button {
            guard let url = URL(string: urlString) else { return }
            NSWorkspace.shared.open(url)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(RebootTheme.subduedText)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.white)
            }
            .rebootCard()
        }
        .buttonStyle(.plain)
    }
}

private struct RebootInfoLine: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(RebootTheme.subduedText)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .textSelection(.enabled)
        }
    }
}

private struct RebootToggleRow: View {
    let title: String
    let subtitle: String
    let isOn: Binding<Bool>

    var body: some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(RebootTheme.subduedText)
            }
        }
        .toggleStyle(.switch)
    }
}

private struct RebootIconButton: View {
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.85), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
