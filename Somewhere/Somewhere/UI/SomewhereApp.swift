//
//  SomewhereApp.swift
//  Somewhere — app entry point.
//  For now the app opens straight to the Wishlist. When Saving and Shelf land,
//  swap WishlistView() for a TabView that holds all three.
//

import SwiftUI
import SwiftData

@main
struct SomewhereApp: App {
    var body: some Scene {
        WindowGroup {
            WishlistView()
                #if DEBUG
                .task { seedSampleItemsOnce() }
                #endif
        }
        .modelContainer(SharedModelContainer.shared)
    }

    #if DEBUG
    /// Debug builds only: fill an empty store with a few fake saves the first
    /// time, so the grid has something to show. Delete them any time — they
    /// won't come back.
    private func seedSampleItemsOnce() {
        let key = "didSeedSampleItems"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let context = SharedModelContainer.shared.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<SavedItem>())) ?? 0
        guard count == 0 else { return }
        SampleData.items().forEach { context.insert($0) }
        try? context.save()
    }
    #endif
}
