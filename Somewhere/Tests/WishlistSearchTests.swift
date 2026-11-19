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

    /// "blue shirt" should find a link save whose title says neither word,
    /// once VisualIndexer has tagged its picture (Vision: "clothing", colour blue).
    func testVisualTags_blueShirtFindsZaraLongSleeves() {
        let zara = item("Zara long-sleeves", category: ItemCategory.guess(from: "Zara long-sleeves"))
        zara.visualTags = "clothing"
        zara.colorName = "blue"
        let redTee = item("Ribbed baby tee", category: .clothes, color: "red")
        let heels = item("Mary Jane pumps")
        heels.visualTags = "high_heel shoes"

        XCTAssertEqual(zara.category, .clothes)   // "sleeves" is a clothes keyword
        XCTAssertEqual(WishlistSearch.filter([zara, redTee, heels], query: WishlistQuery(text: "blue shirt", includeCooling: true)).map(\.title),
                       ["Zara long-sleeves"])
        XCTAssertEqual(WishlistSearch.filter([zara, redTee, heels], query: WishlistQuery(text: "heels", includeCooling: true)).map(\.title),
                       ["Mary Jane pumps"])
    }

    func testVisualTags_extraColourFromPlaid() {
        let plaid = item("Broadcloth shirt", category: .clothes, color: "brown")
        plaid.visualTags = "textile brown blue"
        XCTAssertEqual(WishlistSearch.filter([plaid], query: WishlistQuery(text: "blue shirt", includeCooling: true)).count, 1)
    }

    // MARK: What it is (ItemKind)

    func testItemKind_lastItemWordWins() {
        XCTAssertEqual(ItemKind.detect(title: "Zara long-sleeves")?.name, "long-sleeve top")
        XCTAssertEqual(ItemKind.detect(title: "Poplin shirt dress")?.name, "dress")
        XCTAssertEqual(ItemKind.detect(title: "Oversized denim jacket")?.name, "jacket")
        XCTAssertEqual(ItemKind.detect(title: "Canvas tote bag")?.name, "tote bag")
        XCTAssertEqual(ItemKind.detect(title: "Ribbed Tank Top")?.name, "tank top")
        XCTAssertEqual(ItemKind.detect(title: "Speedcat OG")?.name, nil)
        // Title says nothing → the page description does.
        XCTAssertEqual(ItemKind.detect(title: "The Lou", description: "Relaxed cotton shirt with a boxy fit.")?.name,
                       "shirt")
        // Nothing in the words → Vision.
        XCTAssertEqual(ItemKind.detect(title: "Speedcat OG", visionLabels: [("sneaker", 0.8)])?.name, "sneakers")
    }

    /// The point of ItemKind: "shirt" shouldn't find jeans just because both are clothes,
    /// or because the jeans' description mentions a shirt.
    func testItemKind_shirtDoesNotFindJeans() {
        let top = item("Zara long-sleeves", category: .clothes, color: "blue")
        top.itemType = "long-sleeve top"
        let jeans = item("Straight leg", category: .clothes, color: "blue")
        jeans.itemType = "jeans"
        jeans.pageDescription = "Classic blue jeans. Pairs well with a white shirt."
        let unknown = item("Mystery clothes", category: .clothes, color: "blue")   // no type yet → category still counts

        let all = [top, jeans, unknown]
        func titles(_ q: String) -> [String] {
            WishlistSearch.filter(all, query: WishlistQuery(text: q, sort: .name, includeCooling: true)).map(\.title)
        }
        XCTAssertEqual(titles("blue shirt"), ["Mystery clothes", "Zara long-sleeves"])
        XCTAssertEqual(titles("blue jeans"), ["Mystery clothes", "Straight leg"])
        XCTAssertEqual(titles("blue clothes"), ["Mystery clothes", "Straight leg", "Zara long-sleeves"])
        XCTAssertEqual(titles("classic"), ["Straight leg"])   // description words are searchable
    }
}
