//
//  SavedItem.swift
//  Somewhere — Wishlist
//
//  The one record every part of the app shares.
//  Saving (Mina) creates these, Shelf (Kaitlyn) changes their status,
//  Wishlist (Nicole) shows / searches / edits them.
//
//  ⚠️ Add this file to BOTH targets: the app and the Share Extension.
//

import Foundation
import SwiftData

@Model
final class SavedItem {

    // MARK: Identity
    @Attribute(.unique) var id: UUID = UUID()

    // MARK: What it is
    var title: String = ""
    var brand: String?
    var price: String?

    /// Downscaled JPEG (see `UIImage.wishlistJPEGData()`), kept outside the SQLite file.
    @Attribute(.externalStorage) var imageData: Data?

    /// Product / post link, if the save came from a URL.
    var linkURLString: String?

    // MARK: Where it came from (the "context")
    var sourceAppRaw: String = SourceApp.other.rawValue
    var categoryRaw: String = ItemCategory.other.rawValue
    var createdAt: Date = Date()

    /// "Why I wanted it" — typed note.
    var note: String?
    /// File name (not full path) of the voice note inside `AppGroup.voiceNotesDirectory`.
    var voiceNoteFileName: String?

    /// Text Vision found in a screenshot — makes screenshots searchable.
    var recognizedText: String?
    /// Basic colour family, e.g. "blue", "pink" (Core Image dominant colour → name).
    var colorName: String?
    /// Exact dominant colour, e.g. "#3B63D9", for the swatch.
    var colorHex: String?

    // MARK: Cooling shelf (owned by Kaitlyn)
    var statusRaw: String = ItemStatus.cooling.rawValue
    var shelfReadyAt: Date = Date().addingTimeInterval(SavedItem.defaultCoolingPeriod)
    var decidedAt: Date?

    /// Default time an item rests on the cooling shelf.
    /// Kaitlyn: comes from the user's setting (ShelfSettings.swift, 3 days unless changed).
    static var defaultCoolingPeriod: TimeInterval { ShelfSettings.coolingPeriod }

    init(
        title: String,
        brand: String? = nil,
        price: String? = nil,
        imageData: Data? = nil,
        linkURL: URL? = nil,
        sourceApp: SourceApp = .other,
        category: ItemCategory = .other,
        note: String? = nil,
        voiceNoteFileName: String? = nil,
        recognizedText: String? = nil,
        colorName: String? = nil,
        colorHex: String? = nil,
        createdAt: Date = Date(),
        coolingPeriod: TimeInterval = SavedItem.defaultCoolingPeriod
    ) {
        self.id = UUID()
        self.title = title
        self.brand = brand
        self.price = price
        self.imageData = imageData
        self.linkURLString = linkURL?.absoluteString
        self.sourceAppRaw = sourceApp.rawValue
        self.categoryRaw = category.rawValue
        self.note = note
        self.voiceNoteFileName = voiceNoteFileName
        self.recognizedText = recognizedText
        self.colorName = colorName
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.statusRaw = ItemStatus.cooling.rawValue
        self.shelfReadyAt = createdAt.addingTimeInterval(coolingPeriod)
    }
}

// MARK: - Typed accessors
// Enums are stored as raw strings so #Predicate can filter on them safely.

extension SavedItem {
    var sourceApp: SourceApp {
        get { SourceApp(rawValue: sourceAppRaw) ?? .other }
        set { sourceAppRaw = newValue.rawValue }
    }

    var category: ItemCategory {
        get { ItemCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .kept }
        set {
            statusRaw = newValue.rawValue
            decidedAt = newValue == .cooling ? nil : Date()
        }
    }

    var linkURL: URL? {
        get { linkURLString.flatMap(URL.init(string:)) }
        set { linkURLString = newValue?.absoluteString }
    }

    var voiceNoteURL: URL? {
        guard let voiceNoteFileName else { return nil }
        let url = AppGroup.voiceNotesDirectory.appendingPathComponent(voiceNoteFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Still resting on the cooling shelf (not decided yet).
    var isCooling: Bool { status == .cooling }

    /// Cooling period is over and Kaitlyn's swipe screen should show it.
    var isReadyToDecide: Bool { isCooling && shelfReadyAt <= Date() }

    /// "www.zara.com" → "zara.com"
    var linkHost: String? {
        guard let host = linkURL?.host() else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Small, stable tilt (−1.2°…1.2°) so cards feel like polaroids on a table.
    var tiltDegrees: Double {
        Double(Int(id.uuid.0) % 5 - 2) * 0.6
    }
}
