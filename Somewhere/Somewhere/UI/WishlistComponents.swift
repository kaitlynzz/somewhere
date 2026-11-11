//
//  WishlistComponents.swift
//  Somewhere — small building blocks for the Wishlist page.
//

import SwiftUI
import UIKit

// MARK: - Polaroid card (grid cell)

struct WishlistCard: View {
    let item: SavedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Square, centre-cropped photo
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { ItemImageView(item: item, maxPixel: 500) }
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(alignment: .topLeading) {
                    if item.isCooling { CoolingBadge(item: item).padding(6) }
                }

            Text(item.title)
                .font(Theme.hand(15))
                .foregroundStyle(Theme.ink)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                SourceChip(source: item.sourceApp, compact: true)
                Spacer(minLength: 0)
                Text(item.createdAt, format: .relative(presentation: .named, unitsStyle: .narrow))
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .padding(.bottom, 2)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 5)
        .rotationEffect(.degrees(item.tiltDegrees))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), from \(item.sourceApp.displayName)")
    }
}

// MARK: - Image (async decode + cache)

struct ItemImageView: View {
    let item: SavedItem
    var maxPixel: CGFloat = 600
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                placeholder
            }
        }
        .task(id: item.id) {
            let loaded = await ThumbnailCache.shared.image(for: item, maxPixel: maxPixel)
            withAnimation(.easeOut(duration: 0.2)) { image = loaded }
        }
    }

    private var placeholder: some View {
        ZStack {
            (item.colorHex.map { Color(hex: $0) } ?? Theme.lavender).opacity(0.35)
            Image(systemName: item.category.symbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.inkSoft.opacity(0.6))
        }
    }
}

/// Decodes stored JPEGs off the main thread and keeps the results in memory.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() { cache.countLimit = 300 }

    @MainActor
    func image(for item: SavedItem, maxPixel: CGFloat) async -> UIImage? {
        let key = "\(item.id.uuidString)-\(Int(maxPixel))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = item.imageData else { return nil }   // read model on main actor

        let decoded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let full = UIImage(data: data) else { return nil }
            let longest = max(full.size.width, full.size.height)
            guard longest > maxPixel else { return full.preparingForDisplay() ?? full }
            let scale = maxPixel / longest
            let target = CGSize(width: full.size.width * scale, height: full.size.height * scale)
            return full.preparingThumbnail(of: target) ?? full
        }.value

        if let decoded { cache.setObject(decoded, forKey: key) }
        return decoded
    }

    func invalidate(_ id: UUID) {
        // NSCache can't enumerate keys; clear the sizes we use.
        for size in [500, 1200] { cache.removeObject(forKey: "\(id.uuidString)-\(size)" as NSString) }
    }
}

// MARK: - Chips

struct SourceChip: View {
    let source: SourceApp
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: source.symbol)
            if !compact { Text(source.displayName) }
        }
        .font(.system(size: compact ? 10 : 12, weight: .semibold))
        .foregroundStyle(source.tint)
        .padding(.horizontal, compact ? 6 : 9)
        .padding(.vertical, compact ? 3 : 5)
        .background(source.tint.opacity(0.1), in: Capsule())
        .accessibilityLabel(source.displayName)
    }
}

struct CoolingBadge: View {
    let item: SavedItem

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: item.isReadyToDecide ? "hand.draw" : "moon.zzz")
            Text(item.isReadyToDecide ? "decide" : "cooling")
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(Theme.blue)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .background(Theme.lavender.opacity(0.7), in: Capsule())
    }
}

/// Horizontal "all · clothes · bags & shoes · room · gifts…" filter row.
struct CategoryChips: View {
    @Binding var selection: ItemCategory?
    let counts: [ItemCategory: Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "all", symbol: nil, count: counts.values.reduce(0, +), isOn: selection == nil) {
                    selection = nil
                }
                ForEach(ItemCategory.allCases) { category in
                    let count = counts[category, default: 0]
                    if count > 0 || selection == category {
                        chip(title: category.displayName, symbol: category.symbol,
                             count: count, isOn: selection == category) {
                            selection = (selection == category) ? nil : category
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func chip(title: String, symbol: String?, count: Int, isOn: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
                Text("\(count)").foregroundStyle(isOn ? .white.opacity(0.75) : Theme.inkSoft)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isOn ? .white : Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isOn ? AnyShapeStyle(Theme.pink) : AnyShapeStyle(Theme.paper), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.ink.opacity(isOn ? 0 : 0.08)))
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isOn)
    }
}

// MARK: - Empty states

struct EmptyWishlistView: View {
    enum Kind { case nothingSaved, noResults(String) }
    let kind: Kind

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.periwinkle)
            Text(title)
                .font(Theme.display(22))
                .foregroundStyle(Theme.headlineGradient)
                .multilineTextAlignment(.center)
            Text(message)
                .font(Theme.body(14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }

    private var icon: String {
        if case .nothingSaved = kind { return "sparkles" }
        return "magnifyingglass"
    }

    private var title: String {
        switch kind {
        case .nothingSaved: "nothing here yet"
        case .noResults: "hmm, not finding that one"
        }
    }

    private var message: String {
        switch kind {
        case .nothingSaved:
            "Tap Share in TikTok, Pinterest or Safari and pick somewhere — it'll land right here."
        case .noResults(let text):
            text.isEmpty
                ? "Nothing matches these filters."
                : "Try a colour, a category, or where you saw it — like \u{201C}pink top instagram\u{201D}."
        }
    }
}
