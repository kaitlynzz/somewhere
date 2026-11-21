//
//  LinkMetadata.swift
//  Somewhere — Add (Karan)
//
//  Karan: what a product page tells us about itself — title, description,
//  image, brand, price, site — read out of its Open Graph / meta tags.
//
//  Pure Foundation and pure parsing: no networking, no UI, no side effects,
//  so every rule in here is covered by LinkMetadataTests. The networking
//  lives next door in LinkMetadataFetcher.swift.
//
//  App target only.
//

import Foundation

/// Everything we managed to learn about a link. Any field may be nil.
struct LinkMetadata: Equatable, Sendable {
    var title: String?
    /// The page's own summary, e.g. "Relaxed long-sleeve shirt in cotton poplin."
    /// Says what the thing is when the title doesn't (ItemKind, search).
    var description: String?
    var siteName: String?
    var brand: String?
    var price: String?
    var imageURL: URL?

    var isEmpty: Bool {
        title == nil && description == nil && siteName == nil && brand == nil && price == nil && imageURL == nil
    }
}

enum LinkMetadataParser {

    /// Titles longer than this are product-page spam, not names.
    static let maxTitleLength = 140
    /// Enough for a product summary; skips the size chart / returns policy.
    static let maxDescriptionLength = 500

    // MARK: - Links

    /// "zara.com/shirt" → https://zara.com/shirt.
    /// Also finds the link inside shared text, because Amazon's "copy link"
    /// gives "Ribbed Knit Top - Amazon.com https://a.co/d/abc" rather than a
    /// bare link. Returns nil when there's no web link at all.
    static func normalizedURL(from text: String) -> URL? {
        if let url = singleURL(from: text) { return url }
        return firstLink(in: text)
    }

    /// Every link in a pasted list, one per line, in order, without repeats.
    /// A line like "Ribbed Knit Top - Amazon.com https://a.co/d/abc" counts once
    /// (the a.co link); a line with several full links gives each of them.
    static func allURLs(in text: String) -> [URL] {
        var urls: [URL] = []
        for line in text.split(whereSeparator: \.isNewline).map(String.init) {
            let full = detectedLinks(in: line).filter { $0.contains("://") }.compactMap(singleURL(from:))
            let found = full.isEmpty ? [normalizedURL(from: line)].compactMap { $0 } : full
            for url in found where !urls.contains(url) { urls.append(url) }
        }
        return urls
    }

    /// The first web link written anywhere in `text`. A full "https://…" link
    /// wins over a bare domain, because product names often contain one
    /// ("… - Amazon.com https://a.co/d/abc" should give the a.co link).
    private static func firstLink(in text: String) -> URL? {
        let found = detectedLinks(in: text)
        let full = found.filter { $0.contains("://") }
        for candidate in full + found {
            if let url = singleURL(from: candidate) { return url }
        }
        return nil
    }

    /// The link-looking pieces of `text`, as written.
    private static func detectedLinks(in text: String) -> [String] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }

    /// `text` as one link, or nil.
    private static func singleURL(from text: String) -> URL? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        if !lower.hasPrefix("http://") && !lower.hasPrefix("https://") {
            // Don't quietly turn ftp:// or file:// into https://.
            if lower.contains("://") { return nil }
            trimmed = "https://" + trimmed
        }

        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host(),
              host.contains("."), !host.hasPrefix("."), !host.hasSuffix(".")
        else { return nil }
        return url
    }

    /// "www.zara.com" → "zara.com" (matches SavedItem.linkHost).
    static func displayHost(of url: URL) -> String? {
        guard let host = url.host()?.lowercased() else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    // MARK: - HTML → metadata

    static func parse(html: String, baseURL: URL? = nil) -> LinkMetadata {
        // Meta tags live in <head>; no need to scan a whole megabyte of markup.
        let head = String(html.prefix(400_000))
        let tags = metaTags(in: head)
        var meta = LinkMetadata()

        meta.siteName = clean(firstValue(tags, ["og:site_name", "application-name"]))
        // Karan: called directly rather than passed to flatMap as a method
        // reference — the reference form crosses an isolation boundary and
        // warns under the project's concurrency settings.
        if meta.siteName == nil, let baseURL {
            meta.siteName = displayHost(of: baseURL)
        }
        meta.brand = clean(firstValue(tags, ["product:brand", "og:brand", "brand"]))
        meta.price = price(from: tags)

        if let raw = clean(firstValue(tags, ["og:title", "twitter:title"]) ?? titleTag(in: head)) {
            // "Ribbed Tank | ZARA" reads better as just "Ribbed Tank".
            meta.title = meta.siteName.map { strippingSiteSuffix(from: raw, site: $0) } ?? raw
        }

        meta.description = clean(
            firstValue(tags, ["og:description", "twitter:description", "description"]),
            maxLength: maxDescriptionLength
        )

        if let image = firstValue(tags, [
            "og:image:secure_url", "og:image", "twitter:image", "twitter:image:src",
        ]) {
            meta.imageURL = resolve(image, against: baseURL)
        }

        return meta
    }

    /// Every `<meta>` tag as key → content. First value wins, so the page's own
    /// og: tags beat anything a widget appends later.
    static func metaTags(in html: String) -> [String: String] {
        var result: [String: String] = [:]
        for tag in matches(#"<meta\b[^>]*>"#, in: html).map(\.whole) {
            guard let content = attribute("content", in: tag), !content.isEmpty else { continue }
            for nameAttribute in ["property", "name", "itemprop"] {
                guard let key = attribute(nameAttribute, in: tag)?.lowercased(), !key.isEmpty else { continue }
                if result[key] == nil { result[key] = content }
            }
        }
        return result
    }

    // MARK: - Tidying

    /// Decodes entities, collapses whitespace, trims, and caps the length.
    static func clean(_ text: String?, maxLength: Int = maxTitleLength) -> String? {
        guard let text else { return nil }
        let collapsed = decodeEntities(text)
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(maxLength))
    }

    /// "Ribbed Tank | ZARA" + site "ZARA" → "Ribbed Tank".
    /// Leaves the title alone if stripping would leave almost nothing.
    static func strippingSiteSuffix(from title: String, site: String) -> String {
        for separator in [" | ", " - ", " – ", " — ", " · "] {
            let suffix = separator + site
            guard title.lowercased().hasSuffix(suffix.lowercased()) else { continue }
            let stripped = String(title.dropLast(suffix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if stripped.count >= 3 { return stripped }
        }
        return title
    }

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = text

        let named = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'",
            "&nbsp;": " ", "&hellip;": "…", "&mdash;": "—", "&ndash;": "–",
        ]
        for (entity, value) in named {
            result = result.replacingOccurrences(of: entity, with: value, options: .caseInsensitive)
        }

        for match in matches(#"&#(x?[0-9a-fA-F]+);"#, in: result) {
            guard let digits = match.groups.first.flatMap({ $0 }) else { continue }
            let value = digits.lowercased().hasPrefix("x")
                ? UInt32(digits.dropFirst(), radix: 16)
                : UInt32(digits, radix: 10)
            guard let value, let scalar = Unicode.Scalar(value) else { continue }
            result = result.replacingOccurrences(of: match.whole, with: String(Character(scalar)))
        }
        return result
    }

    // MARK: - Pieces

    private static func price(from tags: [String: String]) -> String? {
        guard let amount = firstValue(tags, [
            "product:price:amount", "og:price:amount", "product:price", "price",
        ])?.trimmingCharacters(in: .whitespacesAndNewlines), !amount.isEmpty else { return nil }

        // Already carries a symbol ("$48", "£12.00") — leave it as the page wrote it.
        if let first = amount.first, !first.isNumber { return clean(amount) }

        let currency = firstValue(tags, ["product:price:currency", "og:price:currency"])?
            .trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch currency {
        case "USD": return "$" + amount
        case "EUR": return "€" + amount
        case "GBP": return "£" + amount
        case "CAD": return "CA$" + amount
        case .some(let code) where !code.isEmpty: return amount + " " + code
        default: return amount
        }
    }

    private static func titleTag(in html: String) -> String? {
        matches(#"<title[^>]*>(.*?)</title>"#, in: html).first?.groups.first.flatMap { $0 }
    }

    private static func firstValue(_ tags: [String: String], _ keys: [String]) -> String? {
        for key in keys {
            if let value = tags[key], !value.trimmingCharacters(in: .whitespaces).isEmpty { return value }
        }
        return nil
    }

    /// Handles absolute, protocol-relative ("//cdn…") and relative ("/img/x.jpg") sources.
    private static func resolve(_ string: String, against base: URL?) -> URL? {
        let value = decodeEntities(string).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.hasPrefix("//") {
            let scheme = base?.scheme ?? "https"
            return URL(string: scheme + ":" + value)
        }
        if let url = URL(string: value), url.scheme != nil { return url }
        if let base { return URL(string: value, relativeTo: base)?.absoluteURL }
        return nil
    }

    private static func attribute(_ name: String, in tag: String) -> String? {
        let pattern = "\\b\(name)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s\"'>]+))"
        guard let match = matches(pattern, in: tag).first,
              let raw = match.groups.compactMap({ $0 }).first else { return nil }
        return decodeEntities(raw)
    }

    // MARK: - Tiny regex helper

    private struct RegexMatch {
        let whole: String
        let groups: [String?]
    }

    private static func matches(_ pattern: String, in text: String) -> [RegexMatch] {
        guard let regex = try? NSRegularExpression(
            pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return [] }

        let string = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: string.length)).map { match in
            var groups: [String?] = []
            if match.numberOfRanges > 1 {
                for index in 1..<match.numberOfRanges {
                    let range = match.range(at: index)
                    groups.append(range.location == NSNotFound ? nil : string.substring(with: range))
                }
            }
            return RegexMatch(whole: string.substring(with: match.range), groups: groups)
        }
    }
}
