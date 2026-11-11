//
//  ShelfDeck.swift
//  Somewhere — Cooling shelf (Kaitlyn)
//
//  The swipe cards: right = keep it, left = let go.
//  Styled like Nicole's wishlist (Theme.swift): polaroid cards, handwritten captions.
//

import SwiftUI

// MARK: - Deck

struct ShelfDeck: View {
    /// Items whose cooling period is over, oldest first.
    let items: [SavedItem]
    var onDecide: (SavedItem, _ keep: Bool) -> Void

    @State private var drag: CGSize = .zero
    /// Cards that already flew off, hidden until the store catches up.
    @State private var gone: Set<UUID> = []

    private let swipeDistance: CGFloat = 110

    private var visible: [SavedItem] {
        Array(items.filter { !gone.contains($0.id) }.prefix(3))
    }

    var body: some View {
        ZStack {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                let isTop = index == 0
                ShelfCard(
                    item: item,
                    dragX: isTop ? drag.width : 0,
                    onKeep: { fly(item, keep: true) },
                    onLetGo: { fly(item, keep: false) }
                )
                .scaleEffect(1 - CGFloat(index) * 0.04, anchor: .bottom)
                .offset(y: CGFloat(index) * 10)
                .offset(isTop ? drag : .zero)
                .rotationEffect(.degrees(isTop ? Double(drag.width / 22) : restingTilt(index)))
                .zIndex(Double(10 - index))
                .allowsHitTesting(isTop)
                .gesture(dragGesture(for: item), including: isTop ? .all : .subviews)
                .accessibilityAction(named: "keep it") { fly(item, keep: true) }
                .accessibilityAction(named: "let go") { fly(item, keep: false) }
            }
        }
        .onChange(of: items.map(\.id)) { _, ids in
            gone.formIntersection(ids)   // so an undone item can come back
        }
    }

    private func restingTilt(_ index: Int) -> Double {
        index.isMultiple(of: 2) ? 1.6 : -1.6
    }

    private func dragGesture(for item: SavedItem) -> some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                let x = value.translation.width
                let flick = value.predictedEndTranslation.width
                if x > swipeDistance || flick > swipeDistance * 2.5 {
                    fly(item, keep: true)
                } else if x < -swipeDistance || flick < -swipeDistance * 2.5 {
                    fly(item, keep: false)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { drag = .zero }
                }
            }
    }

    private func fly(_ item: SavedItem, keep: Bool) {
        withAnimation(.easeIn(duration: 0.22)) {
            drag = CGSize(width: keep ? 600 : -600, height: drag.height + 40)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                gone.insert(item.id)
                drag = .zero
            }
            onDecide(item, keep)
        }
    }
}

// MARK: - Card

/// "the perfect shoes have cooled for 3 days. still want it?"
/// A big polaroid, like the wishlist's item page.
struct ShelfCard: View {
    let item: SavedItem
    var dragX: CGFloat = 0
    var onKeep: () -> Void
    var onLetGo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            photo

            Text(item.title)
                .font(Theme.hand(24))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)

            HStack(spacing: 8) {
                SourceChip(source: item.sourceApp)
                Text("cooled for \(item.daysCooled) \(item.daysCooled == 1 ? "day" : "days")")
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.inkSoft)
                Spacer(minLength: 0)
                if let price = item.price, !price.isEmpty {
                    Text(price)
                        .font(Theme.body(14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
            }

            if let note = item.note, !note.isEmpty {
                Text(note)
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Theme.yellow.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            }

            if let url = item.voiceNoteURL {
                VoiceNoteRow(url: url)
            }

            Text("still want it?")
                .font(Theme.display(26))
                .foregroundStyle(Theme.headlineGradient)
                .padding(.top, 2)

            HStack(spacing: 10) {
                Button(action: onLetGo) {
                    Text("let go")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Theme.paper, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.12)))
                }
                Button(action: onKeep) {
                    Text("keep it")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Theme.ink, in: Capsule())
                }
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .padding(.bottom, 2)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
        .accessibilityElement(children: .contain)
    }

    private var photo: some View {
        Color.clear
            .frame(maxWidth: .infinity, minHeight: 70, maxHeight: .infinity)
            .overlay { ItemImageView(item: item, maxPixel: 1200) }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(alignment: .topLeading) {
                ShelfTimeBadge(text: "ready", symbol: "hand.draw").padding(8)
            }
            .overlay(alignment: .topLeading) {
                stamp("keep it", color: Theme.blue, tilt: -12)
                    .opacity(Double(max(0, min(1, dragX / 90))))
                    .padding(20)
            }
            .overlay(alignment: .topTrailing) {
                stamp("let go", color: Theme.pink, tilt: 12)
                    .opacity(Double(max(0, min(1, -dragX / 90))))
                    .padding(20)
            }
    }

    private func stamp(_ text: String, color: Color, tilt: Double) -> some View {
        Text(text)
            .font(Theme.display(28))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Theme.paper.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color, lineWidth: 3))
            .rotationEffect(.degrees(tilt))
            .accessibilityHidden(true)
    }
}

/// Same look as the wishlist's "cooling" / "decide" badge.
struct ShelfTimeBadge: View {
    let text: String
    var symbol = "moon.zzz"

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
            Text(text)
        }
        .lineLimit(1)
        .fixedSize()
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(Theme.blue)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .background(Theme.lavender.opacity(0.7), in: Capsule())
    }
}
