//
//  HiddenItemsScreen.swift
//  BrewPackageManager
//
//  Restauración de paquetes y actualizaciones ocultas: nada queda enterrado.
//

import SwiftUI

struct HiddenItemsScreen: View {
    @Environment(PackagesStore.self) private var store

    private var hiddenPackages: [PackagesStore.HiddenItem] {
        store.hiddenItems.filter { $0.kind == .package }
    }

    private var hiddenUpdates: [PackagesStore.HiddenItem] {
        store.hiddenItems.filter { $0.kind == .update }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                SectionHeader(title: "Hidden items", detail: "Hidden packages and hidden updates, separated cleanly.")
                if hiddenPackages.isEmpty && hiddenUpdates.isEmpty {
                    ContentUnavailableView(
                        "No hidden items",
                        systemImage: "eye",
                        description: Text("Anything you hide from the overview shows up here.")
                    )
                } else {
                    if !hiddenPackages.isEmpty {
                        group(title: "Hidden packages", items: hiddenPackages) { item in
                            store.unhidePackage(item.package.id)
                        }
                    }
                    if !hiddenUpdates.isEmpty {
                        group(title: "Hidden updates", items: hiddenUpdates) { item in
                            store.unhideUpdate(for: item.package.id)
                        }
                    }
                }
            }
            .padding(AppTheme.pagePadding)
        }
        .navigationTitle("Hidden items")
    }

    private func group(
        title: String,
        items: [PackagesStore.HiddenItem],
        restore: @escaping (PackagesStore.HiddenItem) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.package.displayName)
                            .font(.subheadline.weight(.medium))
                        Text(item.kind.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Restore", systemImage: "eye") {
                        restore(item)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .card()
            }
        }
    }
}
