//
//  SampleData.swift
//  Somewhere — fake saves for SwiftUI previews. App target only.
//

import Foundation
import SwiftData

enum SampleData {

    static func items() -> [SavedItem] {
        let day: TimeInterval = 86_400
        let now = Date()

        let bag = SavedItem(
            title: "The Suede Patchwork Mini Dual Shoulder Bag",
            brand: "Marc Jacobs", price: "$395",
            linkURL: URL(string: "https://www.marcjacobs.com"),
            sourceApp: .tiktok, category: .accessories,
            note: "the one from the 'fall bags' video — fits my phone + wallet",
            colorName: "brown", colorHex: "#7A4A2B",
            createdAt: now.addingTimeInterval(-1 * day)
        )

        let shoes = SavedItem(
            title: "the perfect shoes",
            brand: "Repetto", price: "$310",
            sourceApp: .screenshot, category: .accessories,
            recognizedText: "REPETTO Cendrillon ballerina — Ocean Blue — EU 38",
            colorName: "blue", colorHex: "#4C6A9E",
            createdAt: now.addingTimeInterval(-4 * day)
        )
        shoes.status = .kept

        let top = SavedItem(
            title: "Ribbed baby tee",
            brand: "Brandy Melville", price: "$22",
            linkURL: URL(string: "https://us.brandymelville.com"),
            sourceApp: .instagram, category: .clothes,
            colorName: "pink", colorHex: "#E8A6C1",
            createdAt: now.addingTimeInterval(-2 * day)
        )

        let lamp = SavedItem(
            title: "Mushroom lamp",
            price: "$64",
            linkURL: URL(string: "https://www.urbanoutfitters.com"),
            sourceApp: .pinterest, category: .room,
            note: "for the reading corner",
            colorName: "white", colorHex: "#F2EDE3",
            createdAt: now.addingTimeInterval(-6 * day)
        )
        lamp.status = .kept

        let gift = SavedItem(
            title: "Glass hair claw set",
            price: "$18",
            linkURL: URL(string: "https://www.etsy.com"),
            sourceApp: .safari, category: .gifts,
            note: "Mina's birthday!!",
            colorName: "purple", colorHex: "#B9A6E0",
            createdAt: now.addingTimeInterval(-10 * day)
        )
        gift.status = .kept

        let letGo = SavedItem(title: "Neon windbreaker", sourceApp: .tiktok, category: .clothes)
        letGo.status = .letGo   // hidden from the wishlist

        return [bag, shoes, top, lamp, gift, letGo]
    }

    @MainActor
    static let previewContainer: ModelContainer = {
        let container = try! ModelContainer(
            for: SavedItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        items().forEach { container.mainContext.insert($0) }
        return container
    }()
}
