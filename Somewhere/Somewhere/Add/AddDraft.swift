//
//  AddDraft.swift
//  Somewhere — one thing being added: a link, what the page says about it,
//  and the name / reason the person gives it.
//
//  The add sheet uses one of these for "add one" and a list of them for
//  "add multiple". Each draft looks its own link up, so a list can scan all
//  its links at once without the slow ones holding up the fast ones.
//
//  After it's saved, edits to the name or reason go straight onto the saved
//  item, so you can fill in "why" on the results screen.
//
//  App target only.
//

import Foundation
import Observation
import SwiftData
import UIKit

@MainActor
@Observable
final class AddDraft: Identifiable {

    enum Lookup: Equatable {
        case idle
        case looking
        case found
        case failed(String)
    }

    let id = UUID()

    // MARK: What the person types

    var linkText: String
    var title = "" {
        didSet { if let savedItem, !title.isEmpty { savedItem.title = title } }
    }
    var note = "" {
        didSet {
            let clean = note.trimmingCharacters(in: .whitespacesAndNewlines)
            savedItem?.note = clean.isEmpty ? nil : clean
        }
    }
    /// nil means "let the app guess".
    var categoryOverride: ItemCategory? {
        didSet { if let savedItem, let categoryOverride { savedItem.category = categoryOverride } }
    }

    // MARK: What we found

    private(set) var lookup: Lookup = .idle
    private(set) var metadata: LinkMetadata?
    private(set) var previewImage: UIImage?
    private(set) var savedItem: SavedItem?

    /// A slow lookup must not overwrite a newer one.
    private var lookupToken = UUID()
    /// The link the current metadata belongs to.
    private var lookedUpLink: URL?

    init(linkText: String = "") {
        self.linkText = linkText
    }

    // MARK: Derived

    var parsedLink: URL? { LinkMetadataParser.normalizedURL(from: linkText) }

    var hasText: Bool { !linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Empty is fine (the link is optional); anything typed has to parse.
    var isLinkValid: Bool { !hasText || parsedLink != nil }

    var isLooking: Bool { lookup == .looking }
    var lookupError: String? {
        if case .failed(let message) = lookup { return message }
        return nil
    }

    var source: SourceApp { parsedLink.map(SourceApp.from(url:)) ?? .other }

    /// "zara.com" — the shop, for the "from …" line.
    var host: String? {
        guard let host = parsedLink?.host()?.lowercased() else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Where it's from, as people say it: the brand or site name, else the domain.
    var storeName: String? {
        metadata?.siteName ?? metadata?.brand ?? host
    }

    var guessedCategory: ItemCategory {
        ItemCategory.guess(from: [title, metadata?.brand, metadata?.siteName]
            .compactMap { $0 }
            .joined(separator: " "))
    }

    var category: ItemCategory { categoryOverride ?? savedItem?.category ?? guessedCategory }

    var hasSomethingToSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parsedLink != nil
    }

    // MARK: Lookup

    /// Reads the page behind the link. Does nothing if this link was already read.
    func lookUp() async {
        guard let url = parsedLink else {
            lookup = hasText ? .failed("that doesn't look like a link") : .idle
            return
        }
        if url == lookedUpLink, lookup == .found || lookup == .looking { return }

        let token = UUID()
        lookupToken = token
        lookedUpLink = url
        lookup = .looking

        do {
            let found = try await LinkMetadataFetcher.metadata(for: url)
            guard lookupToken == token else { return }
            metadata = found
            // Never clobber a name the person already typed.
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let foundTitle = found.title {
                title = foundTitle
            }
            if let imageURL = found.imageURL {
                let image = await LinkMetadataFetcher.previewImage(at: imageURL)
                guard lookupToken == token else { return }
                previewImage = image
            }
            lookup = .found
        } catch {
            guard lookupToken == token else { return }
            metadata = nil
            previewImage = nil
            lookup = .failed("couldn't read that page — you can still name it")
        }
    }

    func clearLink() {
        lookupToken = UUID()
        lookedUpLink = nil
        linkText = ""
        metadata = nil
        previewImage = nil
        lookup = .idle
    }

    // MARK: Saving

    /// Saves through SavedItemStore, same as the Share Extension.
    @discardableResult
    func save(in context: ModelContext) throws -> SavedItem {
        if let savedItem { return savedItem }
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = try SavedItemStore.save(
            title: title,
            image: previewImage,
            link: parsedLink,
            pageDescription: metadata?.description,
            source: source,
            category: categoryOverride,
            brand: metadata?.brand,
            price: metadata?.price,
            note: cleanNote.isEmpty ? nil : cleanNote,
            in: context
        )
        savedItem = item
        return item
    }

    /// Takes a saved item back off (the "remove" on the results list).
    func unsave(in context: ModelContext) {
        guard let savedItem else { return }
        SavedItemStore.delete(savedItem, in: context)
        self.savedItem = nil
    }
}
