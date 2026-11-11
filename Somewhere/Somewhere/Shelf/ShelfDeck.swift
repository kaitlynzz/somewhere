//
//  ShelfDeck.swift
//  Somewhere — Cooling shelf (Kaitlyn)
//
//  The swipe cards: right = keep it, left = let go.
//  Built on Muskaan's DesignSystem (SWChoiceButtonStyle, SWSticker, sw colours).
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
struct ShelfCard: View {
    let item: SavedItem
    var dragX: CGFloat = 0
    var onKeep: () -> Void
    var onLetGo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            photo

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .swText(.headline)
                    .lineLimit(2)
                Text("has cooled for \(item.daysCooled) \(item.daysCooled == 1 ? "day" : "days").")
                    .swText(.body, color: .swMuted)
            }

            if let note = item.note, !note.isEmpty {
                Text("“\(note)”")
                    .swText(.voice, color: .swMuted)
                    .lineLimit(2)
            }

            if let url = item.voiceNoteURL {
                VoiceNoteRow(url: url)
            }

            Text("still want it?")
                .font(.custom("Inter-SemiBoldItalic", size: 20))
                .foregroundStyle(Color.swBlue)

            HStack(spacing: 10) {
                Button("let go", action: onLetGo)
                    .buttonStyle(SWChoiceButtonStyle(kind: .light))
                Button("keep it", action: onKeep)
                    .buttonStyle(SWChoiceButtonStyle(kind: .dark))
            }
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.swLine, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        .accessibilityElement(children: .contain)
    }

    private var photo: some View {
        Color.clear
            .frame(maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
            .overlay { ItemImageView(item: item, maxPixel: 900) }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .topLeading) {
                SWSticker(text: "from \(item.sourceApp.displayName)", color: .swStickerMint, tilt: -4)
                    .padding(10)
            }
            .overlay(alignment: .topLeading) {
                stamp("keep it", color: .swBlue, tilt: -12)
                    .opacity(Double(max(0, min(1, dragX / 90))))
                    .padding(18)
            }
            .overlay(alignment: .topTrailing) {
                stamp("let go", color: .swInk, tilt: 12)
                    .opacity(Double(max(0, min(1, -dragX / 90))))
                    .padding(18)
            }
    }

    private func stamp(_ text: String, color: Color, tilt: Double) -> some View {
        Text(text)
            .font(.custom("Inter-ExtraBold", size: 26))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 3))
            .rotationEffect(.degrees(tilt))
            .accessibilityHidden(true)
    }
}
