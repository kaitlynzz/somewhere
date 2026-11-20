//
//  LinkMetadataTests.swift
//  Somewhere — Add (Karan)
//
//  Karan: the link parser is the part most likely to be wrong, because every
//  shop writes its tags differently. These fixtures cover the shapes I found
//  in the wild: og: tags, Twitter cards, bare <title>, single quotes,
//  attributes in the other order, relative images, and HTML entities.
//

import XCTest
@testable import Somewhere

final class LinkMetadataTests: XCTestCase {

    // MARK: - Normalising what people paste

    func testAddsHTTPSWhenMissing() {
        XCTAssertEqual(LinkMetadataParser.normalizedURL(from: "zara.com/shirt")?.absoluteString,
                       "https://zara.com/shirt")
    }

    func testKeepsExistingScheme() {
        XCTAssertEqual(LinkMetadataParser.normalizedURL(from: "http://zara.com")?.absoluteString,
                       "http://zara.com")
    }

    func testTrimsWhitespaceAroundPastedLinks() {
        XCTAssertNotNil(LinkMetadataParser.normalizedURL(from: "  https://tiktok.com/@x/video/1  \n"))
    }

    func testRejectsThingsThatArentWebLinks() {
        XCTAssertNil(LinkMetadataParser.normalizedURL(from: ""))
        XCTAssertNil(LinkMetadataParser.normalizedURL(from: "the perfect shoes"))
        XCTAssertNil(LinkMetadataParser.normalizedURL(from: "ftp://files.example.com"))
        XCTAssertNil(LinkMetadataParser.normalizedURL(from: "localhost"))
    }

    func testDisplayHostDropsWWW() {
        let url = URL(string: "https://www.zara.com/x")!
        XCTAssertEqual(LinkMetadataParser.displayHost(of: url), "zara.com")
    }

    // MARK: - Open Graph

    private let openGraphPage = """
    <html><head>
      <meta property="og:site_name" content="ZARA">
      <meta property="og:title" content="Ribbed Tank Top | ZARA">
      <meta property="og:image" content="https://static.zara.com/photo.jpg">
      <meta property="product:brand" content="Zara">
      <meta property="product:price:amount" content="29.90">
      <meta property="product:price:currency" content="USD">
      <title>should not win</title>
    </head><body></body></html>
    """

    func testReadsOpenGraphTags() {
        let meta = LinkMetadataParser.parse(html: openGraphPage,
                                            baseURL: URL(string: "https://www.zara.com/x"))
        XCTAssertEqual(meta.siteName, "ZARA")
        XCTAssertEqual(meta.brand, "Zara")
        XCTAssertEqual(meta.imageURL?.absoluteString, "https://static.zara.com/photo.jpg")
        XCTAssertFalse(meta.isEmpty)
    }

    func testReadsThePageDescription() {
        let html = """
        <html><head>
        <meta property="og:title" content="Zara long-sleeves">
        <meta property="og:description" content="Relaxed  long-sleeve shirt in cotton &amp; linen.">
        <meta name="description" content="Shop the new collection">
        </head></html>
        """
        let meta = LinkMetadataParser.parse(html: html)
        XCTAssertEqual(meta.description, "Relaxed long-sleeve shirt in cotton & linen.")   // og: wins, cleaned up
    }

    /// "Ribbed Tank Top | ZARA" is the page's title, but the item is a tank top.
    func testStripsTheSiteNameFromTheTitle() {
        let meta = LinkMetadataParser.parse(html: openGraphPage)
        XCTAssertEqual(meta.title, "Ribbed Tank Top")
    }

    func testFormatsPriceWithCurrencySymbol() {
        let meta = LinkMetadataParser.parse(html: openGraphPage)
        XCTAssertEqual(meta.price, "$29.90")
    }

    func testOpenGraphBeatsTheTitleTag() {
        let meta = LinkMetadataParser.parse(html: openGraphPage)
        XCTAssertNotEqual(meta.title, "should not win")
    }

    // MARK: - Pages that aren't so tidy

    func testFallsBackToTitleTagAndTwitterCard() {
        let html = """
        <html><head>
          <meta name='twitter:image' content='/img/bag.jpg'>
          <title>Mini Dual Shoulder Bag</title>
        </head></html>
        """
        let meta = LinkMetadataParser.parse(html: html,
                                            baseURL: URL(string: "https://shop.example.com/p/1"))
        XCTAssertEqual(meta.title, "Mini Dual Shoulder Bag")
        // Single quotes parsed, and a relative image resolved against the page.
        XCTAssertEqual(meta.imageURL?.absoluteString, "https://shop.example.com/img/bag.jpg")
    }

    func testHandlesAttributesInTheOtherOrder() {
        let html = #"<meta content="Suede Boots" property="og:title">"#
        XCTAssertEqual(LinkMetadataParser.parse(html: html).title, "Suede Boots")
    }

    func testResolvesProtocolRelativeImages() {
        let html = #"<meta property="og:image" content="//cdn.example.com/a.jpg">"#
        let meta = LinkMetadataParser.parse(html: html, baseURL: URL(string: "https://example.com"))
        XCTAssertEqual(meta.imageURL?.absoluteString, "https://cdn.example.com/a.jpg")
    }

    func testDecodesHTMLEntities() {
        let html = #"<meta property="og:title" content="Tom &amp; Jerry&#39;s Mug &hellip;">"#
        XCTAssertEqual(LinkMetadataParser.parse(html: html).title, "Tom & Jerry's Mug …")
    }

    func testCollapsesWhitespaceInTitles() {
        let html = "<title>  Linen   \n  Shirt  </title>"
        XCTAssertEqual(LinkMetadataParser.parse(html: html).title, "Linen Shirt")
    }

    func testPriceThatAlreadyHasASymbolIsLeftAlone() {
        let html = #"<meta property="og:price:amount" content="£48.00">"#
        XCTAssertEqual(LinkMetadataParser.parse(html: html).price, "£48.00")
    }

    func testPageWithNothingUsefulIsEmpty() {
        let meta = LinkMetadataParser.parse(html: "<html><body>hi</body></html>")
        XCTAssertTrue(meta.isEmpty)
    }

    func testEmptyContentIsIgnored() {
        let html = #"<meta property="og:title" content=""><title>Real Title</title>"#
        XCTAssertEqual(LinkMetadataParser.parse(html: html).title, "Real Title")
    }

    /// A page can't hand us a 10,000-character "name".
    func testTitleLengthIsCapped() {
        let long = String(repeating: "a", count: 500)
        let title = LinkMetadataParser.parse(html: "<title>\(long)</title>").title
        XCTAssertEqual(title?.count, LinkMetadataParser.maxTitleLength)
    }

    // MARK: - Feeding the existing search

    /// A link save should be findable by brand and by site, through the
    /// search Nicole already wrote — no changes to WishlistSearch.
    func testLinkMetadataMakesAnItemSearchable() {
        let item = SavedItem(
            title: "Ribbed Tank Top",
            brand: "Zara",
            price: "$29.90",
            linkURL: URL(string: "https://www.zara.com/x"),
            sourceApp: .safari,
            category: .clothes
        )
        XCTAssertFalse(WishlistSearch.filter([item], query: .init(text: "zara tank",
                                                                 includeCooling: true)).isEmpty)
    }
}
