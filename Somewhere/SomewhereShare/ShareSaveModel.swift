//
//  ShareSaveModel.swift
//  Somewhere — the state behind the save sheet:
//  pulls the shared screenshot out of the extension context, reads it,
//  pre-fills name + link, and saves through SavedItemStore.
//
//  Karan: this used to handle screenshots only — a share with no image was
//  rejected outright, so you couldn't share a page from Safari to Somewhere.
//  It now also accepts a plain link and fills the sheet in from the page's
//  own Open Graph tags (LinkMetadataFetcher, shared with the in-app add
//  screen). The screenshot path below is untouched.
//
//  Extension target only.
//

import Foundation
import Observation
import SwiftData
import UIKit
import UniformTypeIdentifiers

/// UIImage is immutable once created; this lets us move it across tasks.
struct SendableImage: @unchecked Sendable {
    let value: UIImage
}

@MainActor @Observable
final class ShareSaveModel {

    enum Phase {
        case loading
        case ready
        case failed(String)
    }

    enum SaveState: Equatable {
        case idle, saving, saved
        case failed(String)
    }

    enum SaveError: LocalizedError {
        case appGroupMissing

        var errorDescription: String? {
            "Somewhere's shared storage isn't set up for the share extension yet, so this can't be saved."
        }
    }

    /// Karan: where this share came from. A screenshot and a shared page
    /// need different copy in the sheet and a different source badge.
    enum Origin: Equatable {
        case screenshot
        case link
    }

    // MARK: State the view reads

    private(set) var phase: Phase = .loading
    /// Karan: set as soon as we know whether we were handed a picture or a page.
    private(set) var origin: Origin = .screenshot
    private(set) var image: UIImage?
    /// True while Vision is reading the screenshot.
    private(set) var isReading = false
    private(set) var saveState: SaveState = .idle

    /// Editable. Pre-filled from the screenshot, never overwritten once the person types.
    var title = ""
    var linkText = ""

    private var insights = ImageInsights()
    /// Karan: what a shared page said about itself — title, image, brand, price.
    private(set) var linkMetadata: LinkMetadata?

    // MARK: Derived

    /// Whether the scan found anything to pre-fill (drives the helper text).
    var foundSomething: Bool {
        // Karan: for a shared page, "found something" means the page gave us
        // a name or a picture.
        if origin == .link { return linkMetadata?.title != nil || image != nil }
        return insights.titleGuess != nil || insights.linkGuess != nil
    }

    /// The link as a real URL. Accepts "zara.com/shirt" and adds https://.
    var parsedLink: URL? {
        var text = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host(), host.contains(".")
        else { return nil }
        return url
    }

    /// Empty is fine (link is optional). Non-empty has to parse.
    var isLinkValid: Bool {
        linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parsedLink != nil
    }

    /// Screenshots are "Screenshot" unless the link itself says TikTok / Instagram / Pinterest.
    var source: SourceApp {
        let fromLink = SourceApp.from(url: parsedLink)
        // Karan: a shared page is whatever site it came from — Safari, a shop,
        // wherever. Only a screenshot should fall back to .screenshot.
        // (Before this, sharing a zara.com link would have been labelled
        // "Screenshot", because .safari wasn't in the list below.)
        if origin == .link { return fromLink }
        return [.tiktok, .instagram, .pinterest].contains(fromLink) ? fromLink : .screenshot
    }

    var canSave: Bool {
        guard case .ready = phase else { return false }
        if saveState == .saving || saveState == .saved { return false }
        return isLinkValid
    }

    // MARK: Loading

    func load(from context: NSExtensionContext?) async {
        let items = (context?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }

        // Take the web link if the host app sent one — true both when it comes
        // alongside an image and when it's all we get (Karan).
        if let linkProvider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        }), let url = await Self.loadWebURL(from: linkProvider) {
            linkText = url.absoluteString
        }

        let imageProvider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        })

        // Karan: a picture still wins when there is one — that's the original
        // screenshot flow. A link on its own used to fall straight through to
        // a failure; now it has its own path.
        if let imageProvider {
            await loadScreenshot(from: imageProvider)
        } else if parsedLink != nil {
            await loadSharedPage()
        } else {
            phase = .failed("Somewhere saves pages and screenshots. Try sharing a link or an image.")
        }
    }

    /// The original flow: a screenshot or photo, read with Vision.
    private func loadScreenshot(from provider: NSItemProvider) async {
        guard let loaded = await Self.loadImage(from: provider) else {
            phase = .failed("Somewhere couldn't open that image.")
            return
        }

        origin = .screenshot
        image = loaded.value
        phase = .ready

        // Read the screenshot off the main thread; the sheet is already usable.
        isReading = true
        let result = await Task.detached(priority: .userInitiated) {
            ScreenshotReader.read(loaded)
        }.value
        apply(result)
    }

    /// Karan: someone shared a page rather than a picture — Safari, a shop app,
    /// anywhere with a share button. Show the sheet straight away so it never
    /// feels stuck, then fill it in from the page's own tags using the same
    /// parser the in-app add screen uses.
    ///
    /// Everything here is best-effort: a page that blocks us or says nothing
    /// useful just leaves the fields empty for the person to type, which is
    /// still better than the share being refused outright.
    private func loadSharedPage() async {
        guard let url = parsedLink else {
            phase = .failed("Somewhere couldn't read that link.")
            return
        }

        origin = .link
        phase = .ready
        isReading = true
        defer { isReading = false }

        guard let found = try? await LinkMetadataFetcher.metadata(for: url) else { return }
        linkMetadata = found

        // Never overwrite something the person has already typed.
        if title.trimmingCharacters(in: .whitespaces).isEmpty, let pageTitle = found.title {
            title = pageTitle
        }
        if let imageURL = found.imageURL {
            image = await LinkMetadataFetcher.previewImage(at: imageURL)
        }
    }

    private func apply(_ result: ImageInsights) {
        insights = result
        if title.trimmingCharacters(in: .whitespaces).isEmpty, let guess = result.titleGuess {
            title = guess
        }
        if linkText.trimmingCharacters(in: .whitespaces).isEmpty, let link = result.linkGuess {
            linkText = link.absoluteString
        }
        isReading = false
    }

    // MARK: Saving

    func save() {
        guard canSave else { return }
        saveState = .saving
        do {
            // Without the App Group the extension would write a private copy
            // the app can never see. Better to say so than to lose the save quietly.
            guard FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil
            else { throw SaveError.appGroupMissing }

            let context = ModelContext(SharedModelContainer.shared)
            try SavedItemStore.save(
                title: title,
                image: image,
                link: parsedLink,
                source: source,
                // Karan: brand and price come from the shared page's tags.
                // SavedItemStore already accepted them and WishlistSearch
                // already searches them — nothing ever filled them in before.
                brand: linkMetadata?.brand,
                price: linkMetadata?.price,
                recognizedText: insights.recognizedText,
                colorName: insights.colorName,
                colorHex: insights.colorHex,
                in: context
            )
            saveState = .saved
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }

    // MARK: Item provider helpers

    /// Streams the file from disk and downsamples while decoding, so a big
    /// photo never sits fully decoded in the extension's small memory budget.
    private nonisolated static func loadImage(from provider: NSItemProvider) async -> SendableImage? {
        let fromFile: SendableImage? = await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                if let url, let image = ImageDownsampler.image(at: url, maxPixel: 1400) {
                    continuation.resume(returning: SendableImage(value: image))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
        if let fromFile { return fromFile }

        // Some apps hand over a live UIImage instead of a file.
        guard provider.canLoadObject(ofClass: UIImage.self) else { return nil }
        return await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: SendableImage(
                    value: ImageDownsampler.resized(image, maxPixel: 1400)))
            }
        }
    }

    private nonisolated static func loadWebURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                // Ignore file:// URLs (an image's own file reference is not a link).
                let web = url.flatMap { ["http", "https"].contains($0.scheme?.lowercased() ?? "") ? $0 : nil }
                continuation.resume(returning: web)
            }
        }
    }
}

// MARK: - Image downsampling

enum ImageDownsampler {

    nonisolated static func image(at url: URL, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return nil
        }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // respect EXIF orientation
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, thumbnailOptions as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    nonisolated static func resized(_ image: UIImage, maxPixel: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height) * image.scale
        guard longest > maxPixel else { return image }
        let factor = maxPixel / longest
        let target = CGSize(width: image.size.width * image.scale * factor,
                            height: image.size.height * image.scale * factor)
        return image.preparingThumbnail(of: target) ?? image
    }
}
