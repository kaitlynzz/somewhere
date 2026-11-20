//
//  SomewhereTabBar.swift
//  Somewhere — the bottom bar: wishlist · raised "+" · shelf.
//
//  The system tab bar can't raise a middle button (and on iOS 26+ it floats
//  as a glass capsule), so MainTabView hides it and draws this instead.
//  "+" isn't a tab — it opens the add sheet on top of whichever tab you're on.
//
//  App target only.
//

import SwiftUI

struct SomewhereTabBar: View {
    @Binding var selection: AppTab
    /// Items ready to decide on the shelf (shown as a badge).
    var shelfBadge: Int = 0
    var onAdd: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            tab(.wishlist, title: "wishlist", symbol: "square.grid.2x2", selectedSymbol: "square.grid.2x2.fill")
            addButton
            tab(.shelf, title: "shelf", symbol: "hourglass", selectedSymbol: "hourglass", badge: shelfBadge)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(alignment: .top) {
            Theme.paper
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.ink.opacity(0.08)).frame(height: 1)
                }
                .shadow(color: Theme.ink.opacity(0.06), radius: 10, y: -2)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: Pieces

    private func tab(_ tab: AppTab, title: String, symbol: String, selectedSymbol: String, badge: Int = 0) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? selectedSymbol : symbol)
                    .font(.system(size: 21, weight: .regular))
                    .frame(height: 26)
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 { badgeView(badge) }
                    }
                Text(title)
                    .font(Theme.body(11, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? Theme.blue : Theme.inkSoft)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(badge > 0 ? "\(title), \(badge) ready" : title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Sits above the bar: a blue circle ringed in the bar's colour, so it
    /// looks like the bar bulges up around it.
    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Theme.blue, in: Circle())
                .overlay(Circle().stroke(Theme.paper, lineWidth: 5))
                .shadow(color: Theme.blue.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(RaisedPressStyle())
        .offset(y: -22)
        .padding(.bottom, -22)          // keep the bar its normal height
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Add something")
    }

    private func badgeView(_ count: Int) -> some View {
        Text(count > 9 ? "9+" : "\(count)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .frame(minWidth: 16, minHeight: 16)
            .background(Theme.pink, in: Capsule())
            .offset(x: 10, y: -4)
    }
}

/// Small squish on press so the "+" feels like a physical button.
private struct RaisedPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    VStack {
        Spacer()
        SomewhereTabBar(selection: .constant(.wishlist), shelfBadge: 2, onAdd: {})
    }
    .background(Theme.cream)
}
