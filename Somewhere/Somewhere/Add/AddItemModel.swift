//
//  AddItemModel.swift
//  Somewhere — Add (Karan)
//
//  Karan: the state behind the add screen.
//
//  Holds what you typed and what the link lookup found, then saves it through
//  SavedItemStore — the same call the Share Extension uses, so an item added
//  here is identical to one shared in.
//
//  Nothing in the shared model changes.
//
//  App target only.
//

import Foundation
import Observation
import SwiftData
import UIKit

@MainActor
@Observable
final class AddItemModel {

    enum LookupState: Equatable {
        case idle
        case looking
        case found
        case failed(String)
    }

    enum SaveState: Equatable {
        case editing
        case saving
        case saved(title: String, coolingDays: Int)
        case failed(String)
    }

    // MARK: What the person types

    var linkText = ""
    var title = ""
    var note = ""
    /// nil means "let the app guess from the title".
    var categoryOverride: ItemCategory?

    // MARK: What we found for them

    private(set) var lookupState: LookupState = .idle
    private(set) var metadata: LinkMetadata?
    private(set) var previewImage: UIImage?
    private(set) var saveState: SaveState = .editing

    /// A slow first lookup must not overwrite a newer one. Every lookup
    /// carries a token and only the current token is allowed to write back.
    private var lookupToken = UUID()

    // MARK: Derived

    var parsedLink: URL? { LinkMetadataParser.normalizedURL(from: linkText) }

    /// Empty is fine — the link is optional. Anything typed has to parse.
    var isLinkValid: Bool {
        linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parsedLink != nil
    }

    /// TikTok / Instagram / Pinterest / Safari when there's a link,
    /// otherwise "Somewhere" — reusing the existing SourceApp rules.
    var source: SourceApp {
        parsedLink.map(SourceApp.from(url:)) ?? .other
    }

    /// Where it will be filed if the person doesn't pick a category.
    var guessedCategory: ItemCategory {
        ItemCategory.guess(from: [title, metadata?.brand, metadata?.siteName]
            .compactMap { $0 }
            .joined(separator: " "))
    }

    var hasSomethingToSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parsedLink != nil
    }

    var canSave: Bool {
        saveState != .saving && isLinkValid && hasSomethingToSave
    }

    // MARK: Link lookup

    func lookUp() async {
        guard let url = parsedLink else {
            if !linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lookupState = .failed("That doesn't look like a link.")
            } else {
                lookupState = .idle
            }
            return
        }

        let token = UUID()
        lookupToken = token
        lookupState = .looking

        do {
            let found = try await LinkMetadataFetcher.metadata(for: url)
            guard lookupToken == token else { return }

            metadata = found
            // Never clobber a name the person already typed.
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let foundTitle = found.title {
                title = foundTitle
            }
            lookupState = .found

            if let imageURL = found.imageURL {
                let image = await LinkMetadataFetcher.previewImage(at: imageURL)
                guard lookupToken == token else { return }
                previewImage = image
            }
        } catch {
            guard lookupToken == token else { return }
            metadata = nil
            previewImage = nil
            lookupState = .failed(error.localizedDescription)
        }
    }

    func clearLink() {
        lookupToken = UUID()
        linkText = ""
        metadata = nil
        previewImage = nil
        lookupState = .idle
    }

    // MARK: Saving

    func save(in context: ModelContext) {
        guard canSave else { return }
        saveState = .saving

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let item = try SavedItemStore.save(
                title: cleanTitle,
                image: previewImage,
                link: parsedLink,
                source: source,
                category: categoryOverride,
                brand: metadata?.brand,
                price: metadata?.price,
                note: cleanNote.isEmpty ? nil : cleanNote,
                in: context
            )
            // New saves start on the cooling shelf, so say where it went —
            // otherwise it looks like the save silently failed.
            saveState = .saved(title: item.title, coolingDays: ShelfSettings.coolingDays)
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }

    func reset() {
        lookupToken = UUID()
        linkText = ""
        title = ""
        note = ""
        categoryOverride = nil
        metadata = nil
        previewImage = nil
        lookupState = .idle
        saveState = .editing
    }
}
