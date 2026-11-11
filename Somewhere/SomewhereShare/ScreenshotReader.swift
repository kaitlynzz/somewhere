//
//  ScreenshotReader.swift
//  Somewhere — reads a shared screenshot so the sheet can pre-fill it.
//
//  Vision finds the text; simple rules pick a likely item name and any
//  visible link. Everything it finds is a *suggestion* — the person can
//  edit both fields before saving. The full text is also stored on the
//  item (recognizedText) so the screenshot becomes searchable in Wishlist.
//
//  Extension target only.
//

import Foundation
import UIKit
import Vision

struct ImageInsights: Sendable {
    var titleGuess: String?
    var linkGuess: URL?
    /// All text Vision found (capped), stored on SavedItem.recognizedText.
    var recognizedText: String?
    var colorName: String?
    var colorHex: String?
}

enum ScreenshotReader {

    fileprivate struct Line {
        let text: String
        let box: CGRect          // normalised, origin bottom-left
        let confidence: Float
    }

    nonisolated static func read(_ source: SendableImage) -> ImageInsights {
        var insights = ImageInsights()
        guard let cgImage = source.value.cgImage else { return insights }

        let lines = recognizeLines(in: cgImage)
        insights.titleGuess = bestTitle(from: lines)
        insights.linkGuess = firstLink(in: lines.map(\.text))

        let text = lines.map(\.text).joined(separator: "\n")
        insights.recognizedText = text.isEmpty ? nil : String(text.prefix(2000))

        if let color = DominantColor.find(in: cgImage) {
            insights.colorName = color.name
            insights.colorHex = color.hex
        }
        return insights
    }

    // MARK: Vision

    private nonisolated static func recognizeLines(in image: CGImage) -> [Line] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            return []
        }
        return (request.results ?? []).compactMap { observation in
            guard let best = observation.topCandidates(1).first else { return nil }
            return Line(text: best.string, box: observation.boundingBox, confidence: best.confidence)
        }
    }

    // MARK: Title guess

    /// App chrome that shows up in nearly every social screenshot.
    private static let interfaceWords: Set<String> = [
        "follow", "following", "like", "likes", "comment", "comments", "share", "reply",
        "for you", "live", "search", "send", "save", "saved", "more", "sponsored",
        "add to bag", "add to cart", "buy now", "shop now", "see translation",
        "view all comments", "view more", "explore", "home", "inbox", "profile",
    ]

    /// The biggest line of real words, away from the status bar and home indicator.
    /// Product names are usually the largest text on a shopping screenshot.
    private nonisolated static func bestTitle(from lines: [Line]) -> String? {
        let candidates = lines.compactMap { line -> Line? in
            let text = clean(line.text)
            guard line.confidence >= 0.5,
                  line.box.midY > 0.07, line.box.midY < 0.93,        // skip status bar / tab bar
                  (4...90).contains(text.count),
                  text.split(separator: " ").count >= 2              // "Ribbed baby tee", not "Follow"
            else { return nil }

            let lower = text.lowercased()
            guard !lower.hasPrefix("@"), !lower.hasPrefix("#"),
                  !lower.hasPrefix("http"), !lower.contains("www."),
                  !interfaceWords.contains(lower)
            else { return nil }

            // Mostly letters: drops prices, timestamps, counts like "12.4K 340".
            let letters = text.filter(\.isLetter).count
            guard Double(letters) / Double(text.count) > 0.6 else { return nil }

            return Line(text: text, box: line.box, confidence: line.confidence)
        }
        return candidates.max { $0.box.height < $1.box.height }?.text
    }

    private nonisolated static func clean(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    // MARK: Link guess

    /// A link that is actually visible in the screenshot (e.g. a caption or address bar).
    private nonisolated static func firstLink(in lines: [String]) -> URL? {
        let text = lines.joined(separator: "\n")
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard let url = match.url,
                  let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
                  let host = url.host(), host.contains(".")
            else { continue }
            return url
        }
        return nil
    }
}
