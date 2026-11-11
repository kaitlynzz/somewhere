//
//  WishlistSearchTests.swift
//  Add to the app's unit-test target. Change `Somewhere` to your app module name.
//

import XCTest
@testable import Somewhere

final class WishlistSearchTests: XCTestCase {

    private func item(
        _ title: String,
        source: SourceApp = .safari,
        category: ItemCategory = .other,
        color: String? = nil,
        note: String? = nil,
        text: String? = nil,
        daysAgo: Double = 0
    ) -> SavedItem {
        SavedItem(
            title: title,
            sourceApp: source,
            category: category,
            note: note,
            recognizedText: text,
            colorName: color,
            createdAt: Date().addingTimeInterval(-daysAgo * 86_400)
        )
    }

    func testDeckExample_blueBagFromTikTok() {
        let bag = item("Mini Dual Shoulder Handbag", source: .tiktok, category: .accessories, color: "blue")
        let brownBag = item("Suede Shoulder Bag", source: .tiktok, category: .accessories, color: "brown")
        let blueTop = item("Ribbed Tank", source: .tiktok, category: .clothes, color: "blue")
        let pinBag = item("Canvas Tote", source: .pinterest, category: .accessories, color: "blue")

        let query = WishlistQuery(text: "that blue bag from TikTok")
        let result = WishlistSearch.filter([bag, brownBag, blueTop, pinBag], query: query)

        XCTAssertEqual(result.map(\.title), ["Mini Dual Shoulder Handbag"])
    }

    func testColorSynonymAndCategoryKeyword() {
        let bag = item("Dual Shoulder", category: .accessories, color: "blue")
        XCTAssertTrue(WishlistSearch.matches(bag, tokens: WishlistSearch.tokens(from: "navy purse")))
    }

    func testNoteAndScreenshotTextAreSearchable() {
        let a = item("Lamp", note: "for the reading corner")
        let b = item("IMG_4471", source: .screenshot, text: "AERO LINEN SHIRT $48")
        XCTAssertEqual(WishlistSearch.filter([a, b], query: .init(text: "reading")).count, 1)
        XCTAssertEqual(WishlistSearch.filter([a, b], query: .init(text: "linen shirt")).first?.title, "IMG_4471")
    }

    func testRedDoesNotMatchInsideWords() {
        let a = item("Shared Closet Hanger")
        XCTAssertTrue(WishlistSearch.filter([a], query: .init(text: "red")).isEmpty)
    }

    func testLetGoItemsAreHidden() {
        let a = item("Gone")
        a.status = .letGo
        XCTAssertTrue(WishlistSearch.filter([a], query: .init()).isEmpty)
    }

    func testCategoryAndSourceFiltersAndSort() {
        let old = item("Old Rug", source: .pinterest, category: .room, daysAgo: 5)
        let new = item("New Lamp", source: .pinterest, category: .room, daysAgo: 1)
        let dress = item("Dress", source: .pinterest, category: .clothes)

        var query = WishlistQuery(category: .room, source: .pinterest)
        XCTAssertEqual(WishlistSearch.filter([old, new, dress], query: query).map(\.title), ["New Lamp", "Old Rug"])
        query.sort = .oldest
        XCTAssertEqual(WishlistSearch.filter([old, new, dress], query: query).map(\.title), ["Old Rug", "New Lamp"])
    }

    func testCategoryGuess() {
        XCTAssertEqual(ItemCategory.guess(from: "Marc Jacobs Suede Shoulder Handbag"), .accessories)
        XCTAssertEqual(ItemCategory.guess(from: "Linen midi dress"), .clothes)
        XCTAssertEqual(ItemCategory.guess(from: "Mushroom lamp"), .room)
        XCTAssertEqual(ItemCategory.guess(from: "asdf"), .other)
    }
}
