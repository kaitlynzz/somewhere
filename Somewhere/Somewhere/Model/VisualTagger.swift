//
//  VisualTagger.swift
//  Somewhere — looks at a saved picture so search can find it by what it *is*.
//
//  "blue shirt" should find a save titled "Zara long-sleeves". The title says
//  nothing about shirts or blue, but the picture does. This runs Apple's
//  on-device image classifier (Vision, no download, nothing leaves the phone)
//  plus DominantColor, and returns:
//    • labels   — e.g. "clothing jacket", stored on SavedItem.visualTags and
//                 searched by WishlistSearch (plus any extra colours, for plaid
//                 and prints)
//    • a colour — fills SavedItem.colorName when the save didn't have one
//    • a category guess — files "other" items under clothes / bags & shoes / …
//
//  Vision has no "shirt" or "dress" label: tops come back as "clothing".
//  That's fine — "shirt" is a clothes keyword, so search matches anything
//  filed under clothes.
//
//  App target only (VisualIndexer calls it in the background).
//

import CoreGraphics
import Foundation
import ImageIO
import Vision

nonisolated struct VisualAnalysis: Sendable {
    struct Label: Sendable, Equatable {
        let name: String
        let confidence: Float
    }

    var labels: [Label] = []
    var color: DominantColor.Result?
    /// Every colour family with a real share of the picture, e.g. ["blue", "brown"]
    /// for plaid. Lets "blue shirt" find it even if `color` came out brown.
    var colourFamilies: [String] = []
    /// False when Vision failed (e.g. some Simulators), so the item is retried later.
    var classified = false
}

nonisolated enum VisualTagger {

    /// Labels below this are mostly guesses.
    static let minimumConfidence: Float = 0.3
    static let maxLabels = 10

    static func analyze(_ imageData: Data) -> VisualAnalysis {
        var analysis = VisualAnalysis()
        guard let image = thumbnail(of: imageData) else { return analysis }

        if let labels = classify(image) {
            analysis.labels = labels
            analysis.classified = true
        }
        analysis.color = DominantColor.find(in: image)
        analysis.colourFamilies = DominantColor.colourfulFamilies(in: image)
        return analysis
    }

    // MARK: Vision

    private static func classify(_ image: CGImage) -> [VisualAnalysis.Label]? {
        let request = VNClassifyImageRequest()
        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            return nil
        }
        return (request.results ?? [])
            .filter { $0.confidence >= minimumConfidence }
            .sorted { $0.confidence > $1.confidence }
            .prefix(maxLabels)
            .map { VisualAnalysis.Label(name: $0.identifier, confidence: $0.confidence) }
    }

    /// Decodes straight to a small CGImage. Cheaper than UIImage and plenty for Vision.
    private static func thumbnail(of data: Data, maxPixelSize: Int = 512) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    // MARK: Category guess

    /// Vision labels that clearly point to one of our categories.
    /// (Full list: VNClassifyImageRequest().supportedIdentifiers().)
    static let categoryForLabel: [String: ItemCategory] = {
        var map: [String: ItemCategory] = [:]
        for label in ["clothing", "jacket", "jeans", "hoodie", "suit", "swimsuit",
                      "wedding_dress", "sock", "lab_coat"] {
            map[label] = .clothes
        }
        for label in ["bag", "purse", "wallet", "suitcase", "shoes", "sneaker", "boot",
                      "high_heel", "sandal", "hat", "baseball_hat", "sunhat", "cowboy_hat",
                      "scarf", "sunglasses", "eyeglasses", "jewelry", "watch", "necktie",
                      "bowtie", "glove"] {
            map[label] = .accessories
        }
        for label in ["sofa", "armchair", "chair", "swivel_chair", "lamp", "bed", "bedding",
                      "pillow", "curtain", "vase", "candle", "candlestick", "decorative_plant",
                      "bookshelf", "table", "mug", "tableware"] {
            map[label] = .room
        }
        map["cosmetic_tool"] = .beauty
        return map
    }()

    /// The category the labels add up to, or nil when nothing points anywhere clearly.
    static func category(for labels: [VisualAnalysis.Label]) -> ItemCategory? {
        var scores: [ItemCategory: Float] = [:]
        for label in labels {
            if let category = categoryForLabel[label.name] {
                scores[category, default: 0] += label.confidence
            }
        }
        guard let best = scores.max(by: { $0.value < $1.value }), best.value >= minimumConfidence else {
            return nil
        }
        return best.key
    }
}
