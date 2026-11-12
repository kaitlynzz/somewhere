//
//  OnboardingSteps.swift
//  somewhereapp
//
//  Created by Muskaan Bajaj on 11/10/26.
//

import SwiftUI

// --- 1 · splash screen
struct SplashView: View {
    let onComplete: () -> Void
    @State private var animated = false

    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: -20) {
                        Text("some")
                        Text("where")
                    }
                    .font(.custom("Inter-Black", size: 80))
                    .tracking(-4)
                    .foregroundStyle(Color.swInk)

                    // continuous spinning brand mark
                    AsteriskMark(size: 36)
                        .padding(.top, 84)
                        .rotationEffect(.degrees(animated ? 360 : 0))
                }

                Text("everything you want,\nfinally in one place.")
                    .swText(.headline)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)

            Spacer()

            Text("tap anywhere to continue")
                .swText(.caption, color: .swMuted)
                .padding(.bottom, 32)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onComplete()
        }
        .onAppear {
            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                animated = true
            }
        }
    }
}

// --- 2 · walkthrough page 1: save from anywhere
struct SaveAnywhereStep: View {
    let model: OnboardingModel

    var body: some View {
        VStack(spacing: 0) {
            // section header
            VStack(spacing: 6) {
                Text("save from anywhere.")
                    .swText(.title)
                    .multilineTextAlignment(.center)
                Text("see something you want? tap share in TikTok, Pinterest, Instagram, Safari, or any app.")
                    .swText(.body, color: .swMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer()

            // animated focus-target share sheet
            ShareSheetMock()
                .padding(.horizontal, 24)

            Spacer()
        }
    }
}

// animated share sheet graphic container with app dimming transition
struct ShareSheetMock: View {
    @State private var phase: Int = 0 // 0: default, 1: focus somewhere, 2: saved confirmation

    var body: some View {
        VStack(spacing: 16) {
            // simulated item card
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.swSky)
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.swBlue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("wireless headphones")
                        .font(.custom("Inter-SemiBold", size: 14))
                        .foregroundStyle(Color.swInk)
                    Text("tech.com · $180")
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundStyle(Color.swMuted)
                }
                Spacer()

                HStack(spacing: 6) {
                    if phase == 2 {
                        Text("saved!")
                            .font(.custom("Inter-Bold", size: 11))
                            .foregroundStyle(Color.swBlue)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Image(systemName: phase == 2 ? "checkmark" : "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.swBlue)
                        .padding(8)
                        .background(Color.swBlue50, in: Circle())
                }
            }
            .padding(12)
            .background(Color.swPaper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Divider().overlay(Color.swLine)

            // mock app target icons with focus motion logic
            HStack(spacing: 0) {
                mockAppSlot(title: "Messages", icon: "message.fill", dimmed: phase >= 1)
                mockAppSlot(title: "Notes", icon: "note.text", dimmed: phase >= 1)
                
                // highlighted somewhere app target
                VStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.swInk)
                            .frame(width: 58, height: 58)
                            .scaleEffect(phase >= 1 ? 1.14 : 1.0)
                            .shadow(color: Color.swInk.opacity(phase >= 1 ? 0.35 : 0.1), radius: phase >= 1 ? 12 : 4, x: 0, y: phase >= 1 ? 6 : 2)

                        AsteriskMark(size: 28, color: .white)
                            .rotationEffect(.degrees(phase >= 1 ? 90 : 0))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.swInk.opacity(phase >= 1 ? 0.4 : 0), lineWidth: 2)
                            .scaleEffect(phase >= 1 ? 1.25 : 1.0)
                            .opacity(phase == 1 ? 0.8 : 0)
                    )

                    Text("somewhere*")
                        .font(.custom(phase >= 1 ? "Inter-Bold" : "Inter-Medium", size: 11))
                        .foregroundStyle(Color.swInk)
                }
                .frame(maxWidth: .infinity)

                mockAppSlot(title: "Mail", icon: "envelope.fill", dimmed: phase >= 1)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.swLine, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        .task {
            startAnimationLoop()
        }
    }

    private func startAnimationLoop() {
        Task {
            while !Task.isCancelled {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { phase = 0 }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { phase = 1 }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { phase = 2 }
                try? await Task.sleep(nanoseconds: 1_600_000_000)
            }
        }
    }

    private func mockAppSlot(title: String, icon: String, dimmed: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.swSurfaceSunk)
                    .frame(width: 54, height: 54)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.swMuted.opacity(0.6))
            }
            Text(title)
                .font(.custom("Inter-Regular", size: 11))
                .foregroundStyle(Color.swMuted)
        }
        .frame(maxWidth: .infinity)
        .opacity(dimmed ? 0.22 : 0.6)
        .scaleEffect(dimmed ? 0.92 : 1.0)
        .animation(.easeInOut(duration: 0.4), value: dimmed)
    }
}

// --- 3 · walkthrough page 2: pick your places
struct PlacesStep: View {
    let model: OnboardingModel
    @State private var allPlaces = ["clothes", "room", "gifts", "beauty", "tech", "books", "travel", "someday"]
    @State private var adding = false
    @State private var newPlace = ""

    var body: some View {
        VStack(spacing: 0) {
            // section header
            VStack(spacing: 6) {
                Text("it sorts itself.")
                    .swText(.title)
                    .multilineTextAlignment(.center)
                Text("create spaces for what you're eyeing. new saves land in the right place automatically.")
                    .swText(.body, color: .swMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer(minLength: 16)

            // aspirational wishlist preview box
            VStack(spacing: 12) {
                HStack {
                    Text("your wishlist in action")
                        .font(.custom("Inter-SemiBold", size: 11))
                        .foregroundStyle(Color.swMuted)
                    Spacer()
                    SWSticker(text: "auto-filed", color: .swStickerButter, tilt: -2)
                }

                HStack(spacing: 10) {
                    previewSortTag(item: "arch mirror", category: "room", icon: "sparkles")
                    previewSortTag(item: "headphones", category: "tech", icon: "headphones")
                }
            }
            .padding(16)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.swLine, lineWidth: 1))
            .padding(.horizontal, 24)

            Spacer(minLength: 16)

            // category selector grid
            VStack(spacing: 12) {
                FlowLayout(spacing: 10) {
                    ForEach(allPlaces, id: \.self) { place in
                        let on = model.places.contains(place)
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if on { model.places.remove(place) } else { model.places.insert(place) }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(place)
                                    .font(.custom(on ? "Inter-SemiBold" : "Inter-Medium", size: 15))
                                if on {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                }
                            }
                            .foregroundStyle(on ? Color.swPaper : Color.swInk)
                            .padding(.horizontal, 18)
                            .frame(height: 44)
                            .background(on ? Color.swInk : Color.white, in: Capsule())
                            .overlay(Capsule().stroke(on ? Color.clear : Color.swLine, lineWidth: 1))
                            .shadow(color: on ? Color.black.opacity(0.1) : Color.clear, radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }

                    Button { adding = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                            Text("add place")
                                .font(.custom("Inter-Medium", size: 15))
                        }
                        .foregroundStyle(Color.swMuted)
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(Color.swPaper, in: Capsule())
                        .overlay(Capsule().stroke(Color.swLine, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 16)

            Text("\(model.places.count) places active")
                .font(.custom("Inter-Medium", size: 13))
                .foregroundStyle(Color.swMuted)
                .padding(.bottom, 16)
        }
        .alert("add a place", isPresented: $adding) {
            TextField("e.g. kitchen", text: $newPlace)
            Button("add") {
                let trimmed = newPlace.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !trimmed.isEmpty {
                    if !allPlaces.contains(trimmed) { allPlaces.append(trimmed) }
                    model.places.insert(trimmed)
                }
                newPlace = ""
            }
            Button("cancel", role: .cancel) { newPlace = "" }
        }
    }

    private func previewSortTag(item: String, category: String, icon: String) -> some View {
        let active = model.places.contains(category)
        return HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(active ? Color.swBlue : Color.swMuted)
            VStack(alignment: .leading, spacing: 1) {
                Text(item)
                    .font(.custom("Inter-SemiBold", size: 12))
                    .foregroundStyle(Color.swInk)
                Text(active ? "→ \(category)" : "unfiled")
                    .font(.custom("Inter-Regular", size: 10))
                    .foregroundStyle(active ? Color.swBlue : Color.swMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(active ? Color.swBlue50 : Color.swSurfaceSunk, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// custom wrapping layout for category pills
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// --- 4 · walkthrough page 3: cooling shelf
struct CoolingShelfStep: View {
    let model: OnboardingModel
    @State private var drag: CGSize = .zero
    @State private var verdict: Bool?

    var body: some View {
        VStack(spacing: 0) {
            // section header
            VStack(spacing: 6) {
                Text("the cooling shelf.")
                    .swText(.title)
                    .multilineTextAlignment(.center)
                Text("saves rest for a few days before you decide. less impulse, more intentional.")
                    .swText(.body, color: .swMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer(minLength: 12)

            // swipe visual cue banner
            if verdict == nil {
                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                        Text("swipe to pass")
                    }
                    .font(.custom("Inter-Medium", size: 12))
                    .foregroundStyle(drag.width < -30 ? Color.red : Color.swMuted.opacity(0.7))

                    HStack(spacing: 4) {
                        Text("swipe to keep")
                        Image(systemName: "arrow.right")
                    }
                    .font(.custom("Inter-Medium", size: 12))
                    .foregroundStyle(drag.width > 30 ? Color.swBlue : Color.swMuted.opacity(0.7))
                }
                .padding(.bottom, 8)
            }

            // interactive card stack
            ZStack {
                if let verdict {
                    VStack(spacing: 12) {
                        Text(verdict ? "kept. good decision." : "let go. saved money.")
                            .swText(.headline)
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                self.verdict = nil
                                drag = .zero
                            }
                        } label: {
                            Text("reset card preview")
                                .font(.custom("Inter-SemiBold", size: 14))
                                .foregroundStyle(Color.swInk)
                                .padding(.horizontal, 16)
                                .frame(height: 38)
                                .background(Color.white, in: Capsule())
                                .overlay(Capsule().stroke(Color.swLine, lineWidth: 1))
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    demoCard
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 240)

            Spacer(minLength: 12)

            // feature description banner
            VStack(spacing: 4) {
                Text("automatic 3-day cooling buffer")
                    .font(.custom("Inter-SemiBold", size: 13))
                    .foregroundStyle(Color.swInk)
                Text("gives impulse buys time to fade before you make a move.")
                    .font(.custom("Inter-Regular", size: 12))
                    .foregroundStyle(Color.swMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private var demoCard: some View {
        SWSaveCard(title: "wireless earbuds · $150", tilt: -2 + Double(drag.width) / 18) {
            ZStack {
                Color.swSky
                VStack(spacing: 8) {
                    Image(systemName: "headphones")
                        .font(.system(size: 42))
                        .foregroundStyle(Color.swBlue)
                    Text("safari save")
                        .font(.custom("Inter-Medium", size: 11))
                        .foregroundStyle(Color.swBlue.opacity(0.8))
                }
            }
        }
        .frame(width: 215)
        .overlay(alignment: .topTrailing) {
            SWSticker(text: "\(model.coolingDays) days left", color: .swStickerButter, tilt: 6)
                .offset(x: 14, y: -10)
        }
        .offset(x: drag.width, y: drag.height * 0.15)
        .gesture(
            DragGesture()
                .onChanged { drag = $0.translation }
                .onEnded { value in
                    if value.translation.width > 90 { decide(true) }
                    else if value.translation.width < -90 { decide(false) }
                    else { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { drag = .zero } }
                }
        )
    }

    private func decide(_ keep: Bool) {
        withAnimation(.spring(duration: 0.35)) {
            drag = CGSize(width: keep ? 450 : -450, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.snappy) { verdict = keep }
        }
    }
}
