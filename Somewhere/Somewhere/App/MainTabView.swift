//
//  MainTabView.swift
//  Somewhere — the tabs you see after onboarding.
//
//  wishlist (Nicole) · raised "+" · shelf (Kaitlyn), drawn by SomewhereTabBar.
//  "+" opens Karan's add page (AddItemView) as a bottom sheet over either tab.
//

import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case wishlist
    case shelf
}

/// Lets things outside the views (e.g. a tapped notification) switch tabs.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()
    var selectedTab: AppTab = .wishlist
    /// The add sheet (the raised "+" in the tab bar).
    var isAddingItem = false
}

struct MainTabView: View {
    @State private var router = AppRouter.shared
    @State private var now = Date()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<SavedItem> { $0.statusRaw == "cooling" })
    private var cooling: [SavedItem]

    private var readyCount: Int {
        cooling.filter { $0.shelfReadyAt <= now }.count
    }

    /// Changes whenever a cooling item is added, decided, or re-timed.
    private var reminderKey: [String] {
        cooling.map { "\($0.id)@\($0.shelfReadyAt.timeIntervalSince1970)" }.sorted()
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            WishlistView()
                .tag(AppTab.wishlist)
                .toolbar(.hidden, for: .tabBar)

            ShelfView()
                .tag(AppTab.shelf)
                .toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SomewhereTabBar(selection: $router.selectedTab, shelfBadge: readyCount) {
                router.isAddingItem = true
            }
        }
        // Karan's add page, now a bottom sheet. After a save it shows the
        // "saved" card; swipe down to close.
        .sheet(isPresented: $router.isAddingItem) {
            AddItemView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .tint(Color.swBlue)
        #if DEBUG
        .task { ShelfDebug.handleLaunchArguments(in: context) }
        #endif
        // Tag saved pictures so "blue shirt" finds them (VisualIndexer.swift).
        .task { await VisualIndexer.run(in: context) }
        .task(id: reminderKey) {
            await ShelfNotifications.sync(cooling.map(ShelfNotifications.Reminder.init))
        }
        .task {
            // Keep the "ready" badge current while the app is open.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                now = Date()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            now = Date()
            Task { await ShelfNotifications.sync(cooling.map(ShelfNotifications.Reminder.init)) }
            // Picks up anything saved from the Share Extension while we were away.
            Task { await VisualIndexer.run(in: context) }
        }
    }
}
