//
//  ShelfDebug.swift
//  Somewhere — Cooling shelf (Kaitlyn)
//
//  Test helpers so you don't have to wait 3 days to try the swipe cards.
//  The ladybug menu on the shelf (debug builds only) calls these.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

enum ShelfDebug {

    /// Three saves that are ready to decide on, plus one that's still cooling.
    static func addTestItems(in context: ModelContext) {
        let period = ShelfSettings.coolingPeriod
        let now = Date()
        let ready = now.addingTimeInterval(-period - 3_600)

        let items = [
            SavedItem(title: "the perfect shoes", brand: "Repetto", price: "$310",
                      sourceApp: .tiktok, category: .accessories,
                      note: "for the wedding in may",
                      colorName: "blue", colorHex: "#4C6A9E",
                      createdAt: ready, coolingPeriod: period),
            SavedItem(title: "wireless earbuds", price: "$150",
                      sourceApp: .safari, category: .other,
                      colorName: "white", colorHex: "#E9E6DF",
                      createdAt: ready.addingTimeInterval(-86_400), coolingPeriod: period),
            SavedItem(title: "linen button-up", price: "$48",
                      sourceApp: .instagram, category: .clothes,
                      note: "the one from the summer outfits reel",
                      colorName: "white", colorHex: "#F2EDE3",
                      createdAt: ready.addingTimeInterval(-3_600), coolingPeriod: period),
            SavedItem(title: "mushroom lamp", price: "$64",
                      sourceApp: .pinterest, category: .room,
                      colorName: "brown", colorHex: "#B98A5E",
                      createdAt: now.addingTimeInterval(-3_600), coolingPeriod: period),
        ]
        items.forEach { context.insert($0) }
        try? context.save()
    }

    /// Ends the cooling period for everything on the shelf.
    static func makeAllReady(in context: ModelContext) {
        let cooling = (try? context.fetch(FetchDescriptor<SavedItem>(
            predicate: #Predicate { $0.statusRaw == "cooling" }
        ))) ?? []
        cooling.forEach { $0.shelfReadyAt = Date() }
        try? context.save()
    }

    /// Launch with `-shelfDemo` (Xcode: Edit Scheme → Run → Arguments) to open
    /// straight onto the shelf with the demo items.
    @MainActor
    static func handleLaunchArguments(in context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-shelfDemo") else {
            ensureOneReadyItem(in: context)
            return
        }
        resetToDemo(in: context)
        AppRouter.shared.selectedTab = .shelf
    }

    // MARK: Demo set (for showing the app)

    /// Clears everything, then adds 2 kept items for the wishlist and
    /// 1 item that's ready to decide on the shelf — each with a picture.
    @MainActor
    static func resetToDemo(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<SavedItem>())) ?? []
        all.forEach { SavedItemStore.delete($0, in: context) }

        let day: TimeInterval = 86_400
        let now = Date()
        let period = ShelfSettings.coolingPeriod

        // Wishlist: already decided "keep it"
        let shoes = SavedItem(
            title: "the perfect shoes", brand: "Repetto", price: "$310",
            imageData: demoPhoto("shoe.2.fill", hex: "#4C6A9E")?.wishlistJPEGData(),
            linkURL: URL(string: "https://www.repetto.com"),
            sourceApp: .tiktok, category: .accessories,
            note: "for the wedding in may",
            colorName: "blue", colorHex: "#4C6A9E",
            createdAt: now.addingTimeInterval(-9 * day), coolingPeriod: period
        )
        shoes.status = .kept

        let bag = SavedItem(
            title: "suede mini shoulder bag", brand: "Marc Jacobs", price: "$395",
            imageData: demoPhoto("handbag.fill", hex: "#9A6240")?.wishlistJPEGData(),
            linkURL: URL(string: "https://www.marcjacobs.com"),
            sourceApp: .instagram, category: .accessories,
            note: "fits my phone + wallet",
            colorName: "brown", colorHex: "#9A6240",
            createdAt: now.addingTimeInterval(-6 * day), coolingPeriod: period
        )
        bag.status = .kept

        // Shelf: cooling period just ended, waiting for a swipe
        [shoes, bag, demoReadyItem()].forEach { context.insert($0) }
        try? context.save()
    }

    /// The one demo save whose cooling period just ended.
    @MainActor
    private static func demoReadyItem() -> SavedItem {
        let period = ShelfSettings.coolingPeriod
        return SavedItem(
            title: "wireless earbuds", price: "$150",
            imageData: demoPhoto("headphones", hex: "#D4559A")?.wishlistJPEGData(),
            linkURL: URL(string: "https://www.apple.com"),
            sourceApp: .safari, category: .other,
            note: "my old ones keep cutting out",
            colorName: "pink", colorHex: "#D4559A",
            createdAt: Date().addingTimeInterval(-period - 3_600), coolingPeriod: period
        )
    }

    /// Debug builds: every time the app opens, make sure there's at least one
    /// save on the shelf waiting for a decision, so the swipe cards can be tested.
    @MainActor
    static func ensureOneReadyItem(in context: ModelContext) {
        // Brand-new install: start with the full demo set (2 wishlist + 1 shelf).
        if ((try? context.fetchCount(FetchDescriptor<SavedItem>())) ?? 0) == 0 {
            resetToDemo(in: context)
            return
        }
        let now = Date()
        let readyCount = (try? context.fetchCount(FetchDescriptor<SavedItem>(
            predicate: #Predicate { $0.statusRaw == "cooling" && $0.shelfReadyAt <= now }
        ))) ?? 0
        guard readyCount == 0 else { return }
        context.insert(demoReadyItem())
        try? context.save()
    }

    /// A simple "product photo": the item's colour as a soft backdrop with a big icon.
    /// Real saves get real photos from Mina's Saving flow.
    @MainActor
    private static func demoPhoto(_ symbol: String, hex: String) -> UIImage? {
        let tint = Color(hex: hex)
        let photo = ZStack {
            Color.white   // JPEG has no transparency
            LinearGradient(colors: [tint.opacity(0.18), tint.opacity(0.45)],
                           startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(Color.white.opacity(0.55))
                .frame(width: 460, height: 460)
                .blur(radius: 40)
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .frame(width: 360, height: 360)
                .foregroundStyle(tint)
                .shadow(color: .black.opacity(0.22), radius: 20, y: 16)
        }
        .frame(width: 800, height: 800)

        let renderer = ImageRenderer(content: photo)
        renderer.scale = 1
        return renderer.uiImage
    }

    @MainActor
    static let previewContainer: ModelContainer = {
        let container = try! ModelContainer(
            for: SavedItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        addTestItems(in: container.mainContext)
        return container
    }()
}
