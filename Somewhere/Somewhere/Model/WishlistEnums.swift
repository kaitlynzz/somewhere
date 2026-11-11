//
//  WishlistEnums.swift
//  Somewhere — Wishlist
//
//  ⚠️ Add to BOTH targets: the app and the Share Extension.
//

import Foundation

// MARK: - ItemCategory ("it sorts itself")

enum ItemCategory: String, CaseIterable, Identifiable, Codable {
    case clothes
    case accessories
    case room
    case beauty
    case gifts
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .clothes:     "clothes"
        case .accessories: "bags & shoes"
        case .room:        "room"
        case .beauty:      "beauty"
        case .gifts:       "gifts"
        case .other:       "other"
        }
    }

    var symbol: String {
        switch self {
        case .clothes:     "tshirt"
        case .accessories: "handbag"
        case .room:        "sofa"
        case .beauty:      "sparkles"
        case .gifts:       "gift"
        case .other:       "square.grid.2x2"
        }
    }

    /// Words that point to this category. Used by search ("bag" finds bags)
    /// and by `guess(from:)` when a new save comes in.
    var keywords: [String] {
        switch self {
        case .clothes:
            ["clothes", "clothing", "outfit", "top", "shirt", "tee", "dress", "skirt", "pants",
             "jeans", "shorts", "jacket", "coat", "sweater", "cardigan", "hoodie", "blouse"]
        case .accessories:
            ["bag", "handbag", "purse", "tote", "shoes", "shoe", "sneakers", "heels", "boots",
             "flats", "loafers", "jewelry", "necklace", "earrings", "ring", "bracelet",
             "hat", "scarf", "belt", "sunglasses", "wallet"]
        case .room:
            ["room", "decor", "lamp", "rug", "pillow", "bedding", "sheets", "mirror", "chair",
             "desk", "shelf", "candle", "poster", "plant", "vase", "furniture"]
        case .beauty:
            ["beauty", "makeup", "lipstick", "lip", "gloss", "blush", "skincare", "serum",
             "perfume", "fragrance", "nail", "hair", "moisturizer", "sunscreen"]
        case .gifts:
            ["gift", "gifts", "present", "birthday", "for mom", "for dad", "christmas"]
        case .other:
            []
        }
    }

    /// Cheap keyword guess for a fresh save. Returns `.other` when unsure.
    /// (Saving can replace this with something smarter later.)
    static func guess(from text: String) -> ItemCategory {
        let words = WishlistSearch.tokens(from: text, dropStopWords: false)
        let joined = " " + words.joined(separator: " ") + " "
        var best: (ItemCategory, Int) = (.other, 0)
        for category in allCases where category != .other {
            let hits = category.keywords.filter { joined.contains(" \($0) ") }.count
            if hits > best.1 { best = (category, hits) }
        }
        return best.0
    }
}

// MARK: - Source app ("save from anywhere")

enum SourceApp: String, CaseIterable, Identifiable, Codable {
    case tiktok
    case instagram
    case pinterest
    case safari
    case screenshot
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tiktok:     "TikTok"
        case .instagram:  "Instagram"
        case .pinterest:  "Pinterest"
        case .safari:     "Safari"
        case .screenshot: "Screenshot"
        case .other:      "Somewhere"
        }
    }

    var symbol: String {
        switch self {
        case .tiktok:     "music.note"
        case .instagram:  "camera"
        case .pinterest:  "pin"
        case .safari:     "safari"
        case .screenshot: "camera.viewfinder"
        case .other:      "link"
        }
    }

    /// Extra words people type when they mean this source.
    var searchAliases: [String] {
        switch self {
        case .tiktok:     ["tiktok", "tik tok", "tt"]
        case .instagram:  ["instagram", "insta", "ig", "reel", "reels"]
        case .pinterest:  ["pinterest", "pin", "pins"]
        case .safari:     ["safari", "web", "website", "online"]
        case .screenshot: ["screenshot", "screenshots", "photo", "photos"]
        case .other:      []
        }
    }

    /// Best guess from a link's host, for the Share Extension.
    static func from(url: URL?) -> SourceApp {
        guard let host = url?.host()?.lowercased() else { return .other }
        if host.contains("tiktok") { return .tiktok }
        if host.contains("instagram") { return .instagram }
        if host.contains("pinterest") || host.contains("pin.it") { return .pinterest }
        return .safari
    }
}

// MARK: - Cooling shelf status (Kaitlyn)

enum ItemStatus: String, Codable {
    /// Just saved, resting on the cooling shelf.
    case cooling
    /// Swiped right — still want it.
    case kept
    /// Swiped left — hidden from the wishlist (kept in the store for stats/undo).
    case letGo
}

// MARK: - Sorting

enum WishlistSort: String, CaseIterable, Identifiable {
    case newest, oldest, name

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .newest: "newest first"
        case .oldest: "oldest first"
        case .name:   "A → Z"
        }
    }
}
