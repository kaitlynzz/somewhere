//
//  MainTabView.swift
//  Somewhere — the tabs you see after onboarding.
//
//  For now: wishlist (Nicole) + shelf (Kaitlyn). Saving (Mina) and
//  onboarding (Muskaan) plug in here when the branches are merged.
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
                .tabItem { Label("wishlist", systemImage: "square.grid.2x2") }
                .tag(AppTab.wishlist)

            ShelfView()
                .tabItem { Label("shelf", systemImage: "hourglass") }
                .tag(AppTab.shelf)
                .badge(readyCount)
        }
        .tint(Theme.blue)
        #if DEBUG
        .task { ShelfDebug.handleLaunchArguments(in: context) }
        #endif
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
        }
    }
}
