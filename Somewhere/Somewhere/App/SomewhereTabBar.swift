//
//  SomewhereTabBar.swift
//  Somewhere — the floating Liquid Glass bar: [ wishlist · shelf ]  (+)
//
//  iOS 26 style: the tabs live in one glass capsule, and the "+" is its own
//  glass circle beside it (the same shape Apple uses for a separate search
//  button). It's drawn here rather than by TabView because "+" isn't a tab —
//  it opens the add sheet on top of whichever tab you're on.
//
//  iOS 17–25 has no Liquid Glass, so it falls back to a frosted material.
//
//  App target only.
//

import SwiftUI

struct SomewhereTabBar: View {
    @Binding var selection: AppTab
    /// Items ready to decide on the shelf (shown as a badge).
    var shelfBadge: Int = 0
    var onAdd: () -> Void

    @Namespace private var highlight

    var body: some View {
        GlassGroup {
            HStack(spacing: 12) {
                tabs
                addButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    // MARK: Tabs capsule

    private var tabs: some View {
        HStack(spacing: 4) {
            tab(.wishlist, title: "wishlist", symbol: "square.grid.2x2", selectedSymbol: "square.grid.2x2.fill")
            tab(.shelf, title: "shelf", symbol: "hourglass", selectedSymbol: "hourglass", badge: shelfBadge)
        }
        .padding(4)
        .glassCapsule()
    }

    private func tab(_ tab: AppTab, title: String, symbol: String, selectedSymbol: String, badge: Int = 0) -> some View {
        let isSelected = selection == tab
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = tab }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: isSelected ? selectedSymbol : symbol)
                    .font(.system(size: 19, weight: .medium))
                    .frame(height: 24)
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 { badgeView(badge) }
                    }
                Text(title)
                    .font(SWTextStyle.label.font)
            }
            .foregroundStyle(isSelected ? Color.swBlue : Color.swMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background {
                // The selected tab gets a soft pill that slides between tabs.
                if isSelected {
                    Capsule()
                        .fill(Color.swBlue.opacity(0.12))
                        .matchedGeometryEffect(id: "selected", in: highlight)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(badge > 0 ? "\(title), \(badge) ready" : title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func badgeView(_ count: Int) -> some View {
        Text(count > 9 ? "9+" : "\(count)")
            .font(SWTextStyle.label.font)
            .foregroundStyle(Color.swInk)
            .padding(.horizontal, 5)
            .frame(minWidth: 16, minHeight: 16)
            .background(Color.swStickerPink, in: Capsule())
            .offset(x: 10, y: -4)
    }

    // MARK: "+"

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassCircle(tint: Color.swBlue)
        .accessibilityLabel("Add something")
    }
}

// MARK: - Glass (iOS 26+) with a material fallback

/// Lets neighbouring glass shapes blend into each other like the system bar.
private struct GlassGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 12) { content }
        } else {
            content
        }
    }
}

private extension View {
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        }
    }

    @ViewBuilder
    func glassCircle(tint: Color) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(), in: Circle())
        } else {
            self
                .background(tint, in: Circle())
                .shadow(color: tint.opacity(0.35), radius: 12, y: 5)
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        LinearGradient(colors: [Color.swStickerPink.opacity(0.35), Color.swSky], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        SomewhereTabBar(selection: .constant(.wishlist), shelfBadge: 2, onAdd: {})
    }
}
