//
//  WishlistView.swift
//  Somewhere — the Wishlist page: grid of everything you saved,
//  search ("that blue bag from TikTok") and category / source filters.
//

import SwiftUI
import SwiftData

struct WishlistView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var query = WishlistQuery()
    @State private var path = NavigationPath()
    /// Bumped when the app comes back to the foreground so saves made in the
    /// Share Extension (another process) show up without relaunching.
    @State private var refreshToken = UUID()

    var body: some View {
        NavigationStack(path: $path) {
            WishlistResults(query: $query)
                .id(refreshToken)
                .searchable(text: $query.text,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: Text("that blue bag from TikTok…"))
                .toolbar { toolbarContent }
                .toolbarBackground(Theme.cream, for: .navigationBar)
                .navigationDestination(for: SavedItem.self) { item in
                    ItemDetailView(item: item)
                }
        }
        .tint(Theme.blue)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshToken = UUID() }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort", selection: $query.sort) {
                    ForEach(WishlistSort.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Saved from", selection: $query.source) {
                    Text("anywhere").tag(SourceApp?.none)
                    ForEach(SourceApp.allCases) { source in
                        Label(source.displayName, systemImage: source.symbol).tag(Optional(source))
                    }
                }
                .pickerStyle(.menu)
                Toggle("Show cooling shelf items", isOn: $query.includeCooling)
            } label: {
                Image(systemName: query.source != nil || query.includeCooling
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
            }
            .accessibilityLabel("Sort and filter")
        }
    }
}

// MARK: - Results (owns the @Query so it can be refreshed independently)

private struct WishlistResults: View {
    @Binding var query: WishlistQuery

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<SavedItem> { $0.statusRaw != "letGo" },
           sort: \SavedItem.createdAt, order: .reverse)
    private var items: [SavedItem]

    @State private var itemToDelete: SavedItem?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        // Cooling items live on the Shelf; only show them here if the toggle is on.
        let shelved = items.filter { query.includeCooling || !$0.isCooling }
        let coolingCount = items.count - shelved.count
        let visible = WishlistSearch.filter(items, query: query)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(total: shelved.count, showing: visible.count)
                    .padding(.horizontal, 20)

                if coolingCount > 0 {
                    coolingHint(coolingCount)
                        .padding(.horizontal, 20)
                }

                if !shelved.isEmpty {
                    CategoryChips(selection: $query.category,
                                  counts: WishlistSearch.categoryCounts(shelved))
                }

                if shelved.isEmpty {
                    EmptyWishlistView(kind: .nothingSaved)
                } else if visible.isEmpty {
                    EmptyWishlistView(kind: .noResults(query.text))
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(visible) { item in
                            NavigationLink(value: item) {
                                WishlistCard(item: item)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { contextMenu(for: item) }
                        }
                    }
                    .padding(.horizontal, 20)
                    .animation(.snappy, value: visible.map(\.id))
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.cream.ignoresSafeArea())
        .confirmationDialog(
            "Delete \u{201C}\(itemToDelete?.title ?? "")\u{201D}?",
            isPresented: Binding(get: { itemToDelete != nil },
                                 set: { if !$0 { itemToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    ThumbnailCache.shared.invalidate(item.id)
                    SavedItemStore.delete(item, in: context)
                }
                itemToDelete = nil
            }
        } message: {
            Text("This removes it from somewhere for good.")
        }
    }

    // MARK: Header

    private func header(total: Int, showing: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("my wishlist")
                .font(Theme.display(38))
                .foregroundStyle(Theme.headlineGradient)
            Text(subtitle(total: total, showing: showing))
                .font(Theme.body(14))
                .foregroundStyle(Theme.inkSoft)
                .contentTransition(.numericText())
        }
    }

    /// "2 new saves are cooling on the shelf" — so it's clear where new saves went.
    private func coolingHint(_ count: Int) -> some View {
        Label(count == 1 ? "1 new save is cooling on the shelf"
                         : "\(count) new saves are cooling on the shelf",
              systemImage: "moon.zzz")
            .font(Theme.body(13, weight: .medium))
            .foregroundStyle(Theme.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Theme.lavender, in: Capsule())
    }

    private func subtitle(total: Int, showing: Int) -> String {
        if query.isFiltering { return "\(showing) of \(total) things" }
        return total == 1 ? "1 thing, all in one place" : "\(total) things, all in one place"
    }

    // MARK: Long-press menu

    @ViewBuilder
    private func contextMenu(for item: SavedItem) -> some View {
        if let url = item.linkURL {
            Link(destination: url) { Label("Open link", systemImage: "arrow.up.right.square") }
            ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
        }
        Menu {
            ForEach(ItemCategory.allCases) { category in
                Button {
                    item.category = category
                } label: {
                    Label(category.displayName, systemImage: category.symbol)
                }
            }
        } label: {
            Label("Move to…", systemImage: "folder")
        }
        Divider()
        Button(role: .destructive) {
            itemToDelete = item
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Preview

#Preview("Wishlist") {
    WishlistView()
        .modelContainer(SampleData.previewContainer)
}

#Preview("Empty") {
    WishlistView()
        .modelContainer(for: SavedItem.self, inMemory: true)
}
