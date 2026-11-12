//
//  SharedStore.swift
//  Somewhere — Wishlist
//
//  Where saved items live on the phone.
//  The database sits inside the App Group container so the Share Extension
//  (TikTok / Safari / Pinterest share button) and the main app read and write
//  the SAME store.
//
//  ⚠️ Add to BOTH targets. Turn on the App Groups capability on both targets
//     and use the same identifier as `AppGroup.identifier`.
//

import Foundation
import SwiftData
import UIKit

// MARK: - App Group

enum AppGroup {
    /// Change to match the App Group in Signing & Capabilities.
    static let identifier = "group.com.somewhere.app"

    static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }
        // Falls back to the app's own Documents (e.g. SwiftUI previews, or the
        // capability isn't set up yet). The Share Extension won't see this copy.
        print("⚠️ App Group \(identifier) not configured — check Signing & Capabilities.")
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Voice notes ("why I wanted it") are stored as files here.
    static var voiceNotesDirectory: URL {
        let url = containerURL.appendingPathComponent("VoiceNotes", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

// MARK: - Model container

enum SharedModelContainer {

    static let schema = Schema([SavedItem.self])

    /// The real on-device store. Use in the app AND the Share Extension.
    static let shared: ModelContainer = {
        // Use the shared App Group store once the capability is set up;
        // until then (e.g. first runs in the Simulator) keep a private store.
        let hasAppGroup = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil
        let configuration = ModelConfiguration(
            "Somewhere",
            schema: schema,
            groupContainer: hasAppGroup ? .identifier(AppGroup.identifier) : .none,
            cloudKitDatabase: .none   // local only for now (and keeps @Attribute(.unique) legal)
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not open the Somewhere store: \(error)")
        }
    }()

    // In-memory preview container lives in SampleData.swift (app target only).
}

// MARK: - Save / delete API (used by Saving + Shelf)

enum SavedItemStore {

    /// Creates and saves a new item.
    ///
    /// Mina: call this from the Share Extension and from the in-app "+" button.
    /// ```swift
    /// let context = ModelContext(SharedModelContainer.shared)
    /// try SavedItemStore.save(title: meta.title, image: meta.image,
    ///                         link: url, source: SourceApp.from(url: url),
    ///                         in: context)
    /// ```
    @discardableResult
    static func save(
        title: String,
        image: UIImage? = nil,
        link: URL? = nil,
        source: SourceApp,
        category: ItemCategory? = nil,
        brand: String? = nil,
        price: String? = nil,
        recognizedText: String? = nil,
        colorName: String? = nil,
        colorHex: String? = nil,
        note: String? = nil,
        voiceNoteFileName: String? = nil,
        in context: ModelContext
    ) throws -> SavedItem {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCategory = category
            ?? ItemCategory.guess(from: [cleanTitle, brand, recognizedText].compactMap { $0 }.joined(separator: " "))

        let item = SavedItem(
            title: cleanTitle.isEmpty ? "something I saved" : cleanTitle,
            brand: brand,
            price: price,
            imageData: image?.wishlistJPEGData(),
            linkURL: link,
            sourceApp: source,
            category: resolvedCategory,
            note: note,
            voiceNoteFileName: voiceNoteFileName,
            recognizedText: recognizedText,
            colorName: colorName?.lowercased(),
            colorHex: colorHex
        )
        context.insert(item)
        try context.save()
        return item
    }

    /// Deletes the item and its voice-note file.
    static func delete(_ item: SavedItem, in context: ModelContext) {
        if let url = item.voiceNoteURL {
            try? FileManager.default.removeItem(at: url)
        }
        context.delete(item)
        try? context.save()
    }

    /// Kaitlyn: call after a swipe on the cooling shelf.
    static func decide(_ item: SavedItem, keep: Bool, in context: ModelContext) {
        item.status = keep ? .kept : .letGo
        try? context.save()
    }
}

// MARK: - Image downscaling

extension UIImage {
    /// JPEG small enough to store many of and to load inside the Share
    /// Extension's tight memory limit. Longest side ≤ `maxDimension` px.
    func wishlistJPEGData(maxDimension: CGFloat = 1400, quality: CGFloat = 0.8) -> Data? {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return jpegData(compressionQuality: quality) }

        let scale = maxDimension / longest
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
