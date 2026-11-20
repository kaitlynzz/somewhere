//
//  SaveSuccessView.swift
//  Somewhere — what the add sheet shows once something is saved.
//
//  A check that draws itself in (ring → tick → little burst of dots), the
//  "resting on your shelf" explanation, and one button: add another.
//  Closing is a swipe down on the sheet. Respects Reduce Motion.
//
//  App target only.
//

import SwiftUI

struct SaveSuccessView: View {
    let title: String
    let coolingDays: Int
    var onAddAnother: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ring: CGFloat = 0
    @State private var tick: CGFloat = 0
    @State private var popped = false
    @State private var burst = false

    var body: some View {
        VStack(spacing: 14) {
            checkmark
                .frame(height: 170)
                .accessibilityHidden(true)

            Text("saved!")
                .font(Theme.display(34))
                .foregroundStyle(Theme.headlineGradient)

            Text("\u{201C}\(title)\u{201D} is resting on your shelf for \(coolingDays) \(coolingDays == 1 ? "day" : "days").")
                .font(Theme.body(16))
                .multilineTextAlignment(.center)

            Text("when the time's up you'll decide to keep it or let it go.")
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)

            Button(action: onAddAnother) {
                Label("add another", systemImage: "plus")
                    .font(Theme.body(16, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.blue, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .onAppear(perform: play)
    }

    // MARK: The animated check

    private static let dotColours: [Color] = [Theme.pink, Theme.blue, Theme.sun, Theme.periwinkle, Theme.green]

    private var checkmark: some View {
        ZStack {
            // Burst: dots fly out from behind the circle and fade.
            ForEach(0..<12, id: \.self) { i in
                Circle()
                    .fill(Self.dotColours[i % Self.dotColours.count])
                    .frame(width: i.isMultiple(of: 2) ? 9 : 6)
                    .offset(y: burst ? -78 : -24)
                    .rotationEffect(.degrees(Double(i) * 30))
                    .opacity(burst ? 0 : 1)
            }

            Circle()
                .fill(Theme.greenSoft)
                .frame(width: 104, height: 104)
                .scaleEffect(popped ? 1 : 0.5)

            Circle()
                .trim(from: 0, to: ring)
                .stroke(Theme.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 104, height: 104)
                .scaleEffect(popped ? 1 : 0.5)

            CheckShape()
                .trim(from: 0, to: tick)
                .stroke(Theme.green, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .frame(width: 44, height: 34)
        }
    }

    private func play() {
        guard !reduceMotion else {
            ring = 1; tick = 1; popped = true; burst = true
            return
        }
        // Starts just after the sheet's form has faded out (AddItemView.successIn).
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.15)) { popped = true }
        withAnimation(.easeOut(duration: 0.45).delay(0.2)) { ring = 1 }
        withAnimation(.easeOut(duration: 0.3).delay(0.55)) { tick = 1 }
        withAnimation(.easeOut(duration: 0.7).delay(0.6)) { burst = true }
    }
}

/// A tick, drawn left → bottom → top-right so `trim` animates it like a pen stroke.
private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

#Preview {
    SaveSuccessView(title: "Zara long-sleeves", coolingDays: 3, onAddAnother: {})
        .padding(20)
        .background(Theme.cream)
}
