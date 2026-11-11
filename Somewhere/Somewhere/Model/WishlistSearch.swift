//
//  WishlistSearch.swift
//  Somewhere — Wishlist
//
//  "that blue bag from TikTok" → blue (colour) + bag (category word) + TikTok (source).
//  Every meaningful word must match *something* about the item:
//  title, brand, note, screenshot text, colour, source app, category, link host.
//
//  Pure Foundation, so it's unit-testable and safe to add to both targets.
//

import Foundation

struct WishlistQuery: Equatable {
    var text: String = ""
    var category: ItemCategory? = nil
    var source: SourceApp? = nil
    var sort: WishlistSort = .newest
    /// Show items that are still resting on the cooling shelf.
    var includeCooling: Bool = true

    var isFiltering: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty || category != nil || source != nil
    }
}

enum WishlistSearch {

    // MARK: Filtering

    static func filter(_ items: [SavedItem], query: WishlistQuery) -> [SavedItem] {
        let tokens = tokens(from: query.text)

        let matched = items.filter { item in
            if item.status == .letGo { return false }
            if !query.includeCooling && item.isCooling { return false }
            if let category = query.category, item.category != category { return false }
            if let source = query.source, item.sourceApp != source { return false }
            return matches(item, tokens: tokens)
        }

        switch query.sort {
        case .newest: return matched.sorted { $0.createdAt > $1.createdAt }
        case .oldest: return matched.sorted { $0.createdAt < $1.createdAt }
        case .name:   return matched.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    /// Item counts per category (ignores let-go items). Drives the chip badges.
    static func categoryCounts(_ items: [SavedItem]) -> [ItemCategory: Int] {
        items.filter { $0.status != .letGo }
            .reduce(into: [:]) { $0[$1.category, default: 0] += 1 }
    }

    // MARK: Matching

    static func matches(_ item: SavedItem, tokens: [String]) -> Bool {
        guard !tokens.isEmpty else { return true }
        let text = haystack(for: item)
        return tokens.allSatisfy { token in
            let forms = variants(of: token)
            // Word-prefix match: "blu" finds "blue", but "red" doesn't hit "shared".
            if forms.contains(where: { text.contains(" " + $0) }) { return true }
            // "purse" finds a bag even if the title only says "Mini Dual Shoulder".
            return forms.contains { item.category.keywords.contains($0) }
        }
    }

    /// Everything we know about an item, normalised into one searchable string.
    static func haystack(for item: SavedItem) -> String {
        var parts: [String] = [
            item.title,
            item.brand ?? "",
            item.price ?? "",
            item.note ?? "",
            item.recognizedText ?? "",
            item.colorName ?? "",
            item.linkHost ?? "",
            item.sourceApp.displayName,
            item.category.displayName,
            item.category.rawValue,
        ]
        parts += item.sourceApp.searchAliases
        if item.isCooling { parts.append("cooling shelf new") }
        return " " + normalize(parts.joined(separator: " ")) + " "
    }

    // MARK: Text helpers

    /// Words that carry no meaning in "that blue bag I saved from TikTok".
    static let stopWords: Set<String> = [
        "a", "an", "the", "that", "this", "those", "these", "my", "i", "me", "it", "its",
        "from", "on", "in", "at", "of", "for", "with", "to", "and", "or",
        "saved", "save", "found", "saw", "seen", "thing", "things", "one",
    ]

    /// Colour words people use → the basic colour family we store in `colorName`.
    static let colorSynonyms: [String: String] = [
        "navy": "blue", "cobalt": "blue", "denim": "blue", "teal": "blue", "sky": "blue",
        "baby": "blue", "periwinkle": "blue",
        "rose": "pink", "blush": "pink", "fuchsia": "pink", "magenta": "pink",
        "burgundy": "red", "maroon": "red", "wine": "red", "cherry": "red",
        "tan": "brown", "beige": "brown", "camel": "brown", "chocolate": "brown", "mocha": "brown",
        "cream": "white", "ivory": "white", "offwhite": "white",
        "charcoal": "gray", "grey": "gray", "silver": "gray",
        "olive": "green", "sage": "green", "mint": "green", "emerald": "green",
        "lavender": "purple", "lilac": "purple", "violet": "purple",
        "gold": "yellow", "mustard": "yellow", "butter": "yellow",
        "coral": "orange", "peach": "orange",
    ]

    /// Lowercase, accent-free, punctuation → spaces.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let cleaned = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(cleaned)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    static func tokens(from text: String, dropStopWords: Bool = true) -> [String] {
        let words = normalize(text).split(separator: " ").map(String.init)
        return dropStopWords ? words.filter { !stopWords.contains($0) } : words
    }

    /// A token plus forgiving variants: plural/singular and colour family.
    static func variants(of token: String) -> [String] {
        var result = [token]
        if token.count > 4, ["ses", "xes", "ches", "shes"].contains(where: token.hasSuffix) {
            result.append(String(token.dropLast(2)))   // dresses → dress
        }
        if token.count > 3, token.hasSuffix("s") { result.append(String(token.dropLast())) }
        if let family = colorSynonyms[token] { result.append(family) }
        return result
    }
}
