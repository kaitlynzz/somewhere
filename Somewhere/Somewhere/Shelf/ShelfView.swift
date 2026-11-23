//
//  ShelfView.swift
//  Somewhere — Cooling shelf (Kaitlyn)
//
//  The shelf tab:
//  • top: swipe cards for saves whose cooling period is over
//  • bottom: the "still cooling" shelf, with time left on each save
//  • tap a cooling save to see its details, add a note / voice note on why
//    you wanted it, or decide early (keep it / let it go)
//  The page scrolls, and the swipe card has a fixed size, so it doesn't
//  shrink as the "still cooling" shelf fills up.
//  • toolbar: change the waiting period and turn on reminders
//
//  Updated to use DesignSystem.swift (Muskaan).
//

import SwiftUI
import SwiftData
import UserNotifications

struct ShelfView: View {
    @Environment(\.modelContext) private var context

    @Query(
        filter: #Predicate<SavedItem> { $0.statusRaw == "cooling" },
        sort: \SavedItem.shelfReadyAt
    )
    private var cooling: [SavedItem]

    @State private var toast: DecisionToast?
    @State private var selected: SavedItem?
    @State private var showSettings = false
    @State private var coolingDays = ShelfSettings.coolingDays
    @State private var reminderStatus: UNAuthorizationStatus = .authorized   // no prompt flash on load

    var body: some View {
        Group {
            // Re-checks every minute so cards appear the moment they're ready.
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let now = timeline.date
                let ready = cooling.filter { $0.shelfReadyAt <= now }
                let waiting = cooling.filter { $0.shelfReadyAt > now }

                ScrollView {
                    VStack(spacing: 0) {
                        header(readyCount: ready.count)

                        if ready.isEmpty {
                            emptyState(next: waiting.first)
                                .padding(.vertical, 56)
                        } else {
                            ShelfDeck(items: ready, onDecide: decide)
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                                .padding(.bottom, 20)   // room for the cards stacked behind
                            swipeHint
                        }

                        if reminderStatus == .notDetermined && !cooling.isEmpty {
                            reminderPrompt
                        }

                        if !waiting.isEmpty {
                            coolingShelf(waiting, now: now)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .background(Color.swPaper.ignoresSafeArea())
            .overlay(alignment: .bottom) { toastView }
        }
        .tint(Color.swBlue)
        .sensoryFeedback(trigger: toast) { _, new in
            new.map { $0.keep ? .success : .impact(weight: .light) }
        }
        .sheet(item: $selected) { item in
            CoolingItemSheet(
                item: item,
                onLetGo: { decide(item, keep: false) },
                onKeep: { decide(item, keep: true) }
            )
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            coolingDays = ShelfSettings.coolingDays
            Task { reminderStatus = await ShelfNotifications.authorizationStatus() }
        }) {
            ShelfSettingsSheet()
        }
        .task { reminderStatus = await ShelfNotifications.authorizationStatus() }
    }

    // --- header + toolbar

    private func header(readyCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            topButtons
            Text("the cooling shelf")
                .swText(.display)
            Text(readyCount > 0
                 ? "\(readyCount) \(readyCount == 1 ? "thing has" : "things have") cooled off"
                 : "things rest here for \(coolingDays) \(coolingDays == 1 ? "day" : "days") before you decide")
                .swText(.caption, color: .swMuted)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    /// Top-right buttons, in the same frosted capsule as the wishlist's toolbar.
    private var topButtons: some View {
        HStack {
            Spacer()
            HStack(spacing: 18) {
                #if DEBUG
                Menu {
                    Button("reset to demo items", systemImage: "sparkles") { ShelfDebug.resetToDemo(in: context) }
                    Button("add test saves", systemImage: "plus") { ShelfDebug.addTestItems(in: context) }
                    Button("make everything ready now", systemImage: "forward.end") { ShelfDebug.makeAllReady(in: context) }
                    Button("replay onboarding", systemImage: "arrow.counterclockwise") {
                        UserDefaults.standard.set(false, forKey: "somewhere.isLoggedIn")
                    }
                } label: {
                    Image(systemName: "ladybug")
                }
                .accessibilityLabel("Debug tools")
                #endif
                Button { showSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Shelf settings")
            }
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(Color.swBlue)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.swLine, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
        .padding(.bottom, 4)
    }

    private var swipeHint: some View {
        HStack(spacing: 20) {
            Label("let go", systemImage: "arrow.left")
            Label { Text("keep it") } icon: { Image(systemName: "arrow.right") }
                .labelStyle(TrailingIconLabelStyle())
        }
        .swText(.chip, color: .swMuted)
        .padding(.bottom, 12)
        .accessibilityHidden(true)
    }

    // --- empty

    private func emptyState(next: SavedItem?) -> some View {
        VStack(spacing: 14) {
            Image(systemName: next == nil ? "sparkles" : "moon.zzz")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color.swBlue)
            Text(next == nil ? "nothing cooling yet" : "nothing to decide yet")
                .swText(.title)
                .multilineTextAlignment(.center)
            Group {
                if let next {
                    Text("next one's ready \(next.shelfReadyAt, format: .relative(presentation: .named)).")
                } else {
                    Text("New saves rest here for a few days, so impulse buys have time to fade.")
                }
            }
            .swText(.caption, color: .swMuted)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    // --- reminders

    private var reminderPrompt: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.swBlue)
            Text("get a nudge when something's ready")
                .swText(.caption)
            Spacer(minLength: 8)
            Button("turn on") {
                Task {
                    await ShelfNotifications.requestPermission()
                    reminderStatus = await ShelfNotifications.authorizationStatus()
                    await ShelfNotifications.sync(cooling.map(ShelfNotifications.Reminder.init))
                }
            }
            .swText(.caption, color: .swPaper)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Color.swInk, in: Capsule())
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.swLine, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // --- still cooling

    private func coolingShelf(_ items: [SavedItem], now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("STILL COOLING")
                    .swText(.label, color: .swBlue)
                Text("\(items.count)")
                    .swText(.chip, color: .swMuted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(items) { item in
                        Button { selected = item } label: {
                            CoolingTile(item: item, now: now)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
        }
        .background(Color.swSky.opacity(0.65))
    }

    // --- decide + undo

    private func decide(_ item: SavedItem, keep: Bool) {
        SavedItemStore.decide(item, keep: keep, in: context)
        withAnimation(.snappy) { toast = DecisionToast(item: item, keep: keep) }
    }

    private func undo(_ toast: DecisionToast) {
        toast.item.status = .cooling
        try? context.save()
        withAnimation(.snappy) { self.toast = nil }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            HStack(spacing: 14) {
                Text(toast.keep ? "kept. good decision." : "let go. saved money.")
                    .swText(.bodyStrong, color: .swPaper)
                Spacer(minLength: 8)
                Button("undo") { undo(toast) }
                    .swText(.bodyStrong, color: .swStickerButter)
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .background(Color.swInk, in: Capsule())
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: toast.id) {
                try? await Task.sleep(for: .seconds(3.5))
                withAnimation(.snappy) { if self.toast?.id == toast.id { self.toast = nil } }
            }
        }
    }
}

struct DecisionToast: Equatable {
    let id = UUID()
    let item: SavedItem
    let keep: Bool

    static func == (a: Self, b: Self) -> Bool { a.id == b.id }
}

// --- cooling tile

/// A small polaroid on the "still cooling" shelf — same look as a wishlist card.
struct CoolingTile: View {
    let item: SavedItem
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .frame(width: 96, height: 96)
                .overlay { ItemImageView(item: item, maxPixel: 500) }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .topLeading) {
                    ShelfTimeBadge(text: timeLeft).padding(5)
                }
                .overlay(alignment: .bottomTrailing) {
                    if item.voiceNoteURL != nil {
                        Image(systemName: "waveform")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(Color.swStickerPink, in: Circle())
                            .padding(5)
                    }
                }

            Text(item.title)
                .swText(.caption)
                .lineLimit(1)
                .frame(width: 96, alignment: .leading)
        }
        .padding(7)
        .padding(.bottom, 2)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.swLine, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        .rotationEffect(.degrees(item.tiltDegrees))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(timeLeft)")
        .accessibilityHint("Add a note on why you want it")
    }

    private var timeLeft: String { CoolingTile.timeLeft(until: item.shelfReadyAt, now: now) }

    /// "3 days left" / "5h left" / "almost ready".
    static func timeLeft(until readyAt: Date, now: Date) -> String {
        let seconds = readyAt.timeIntervalSince(now)
        if seconds >= 82_800 {   // 23h+ reads as "1 day left"
            let days = Int((seconds / 86_400).rounded(.up))
            return "\(days) \(days == 1 ? "day" : "days") left"
        }
        if seconds >= 3_600 { return "\(Int((seconds / 3_600).rounded(.up)))h left" }
        return "almost ready"
    }
}

// --- section card

struct ShelfSectionCard<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .swText(.label, color: .swBlue)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.swLine, lineWidth: 1))
    }
}

// --- cooling item sheet

/// A save that's still cooling: its details, "why I wanted it" (note + voice
/// note), and a way to decide early.
struct CoolingItemSheet: View {
    let item: SavedItem
    var onLetGo: () -> Void
    var onKeep: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Polaroid. The photo fills a fixed box and is cropped to it —
                // a filled image inside .frame(maxWidth: .infinity) grows to its
                // own width, which pushed wide photos off the screen.
                VStack(spacing: 12) {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .overlay { ItemImageView(item: item, maxPixel: 1200) }
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    Text(item.title)
                        .swText(.headline)
                        .lineLimit(1)
                        .padding(.bottom, 6)
                }
                .padding(12)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.swLine, lineWidth: 1))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                .rotationEffect(.degrees(item.tiltDegrees))
                .padding(.horizontal, 6)

                ShelfSectionCard(label: "THE COOLING SHELF") {
                    TimelineView(.periodic(from: .now, by: 60)) { timeline in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(CoolingTile.timeLeft(until: item.shelfReadyAt, now: timeline.date))
                                .swText(.title)
                            Text("ready \(item.shelfReadyAt, format: .dateTime.weekday(.wide).hour().minute())")
                                .swText(.body, color: Color.swMuted)
                        }
                    }

                    Divider().overlay(Color.swLine)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("why I wanted it")
                            .swText(.bodyStrong, color: .swBlue)

                        TextField("wore it to… / perfect for… / because…", text: noteBinding, axis: .vertical)
                            .swText(.voice)
                            .lineLimit(2...6)
                            .padding(12)
                            .background(Color.swStickerButter.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VoiceNoteRecorderView(item: item)
                    }
                }

                CoolingItemDetails(item: item)

                VStack(spacing: 4) {
                    Button {
                        dismiss()
                        onLetGo()
                    } label: {
                        Text("let go now")
                            .swText(.bodyStrong)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white, in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.swLine))
                    }

                    // Secondary: skip the wait and keep it.
                    Button {
                        dismiss()
                        onKeep()
                    } label: {
                        Label("add to wishlist now", systemImage: "heart")
                            .swText(.bodyStrong, color: .swBlue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.swPaper.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .onDisappear { try? context.save() }
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { item.note ?? "" },
            set: { item.note = $0.isEmpty ? nil : $0 }
        )
    }
}

// MARK: - Cooling item details

/// The same facts the wishlist's item page shows, read-only: what it is,
/// where it's from, price, colour.
struct CoolingItemDetails: View {
    let item: SavedItem
    @Environment(\.openURL) private var openURL

    var body: some View {
        ShelfSectionCard(label: "DETAILS") {
            if let type = item.itemType {
                row("what it is") { Text(type) }
            }
            row("category") {
                Label(item.category.displayName, systemImage: item.category.symbol)
            }
            if let price = item.price, !price.isEmpty {
                row("price") { Text(price).fontWeight(.semibold) }
            }
            if let brand = item.brand, !brand.isEmpty {
                row("brand") { Text(brand) }
            }
            row("saved from") {
                Label(item.sourceApp.displayName, systemImage: item.sourceApp.symbol)
            }
            if let host = item.linkHost, let url = item.linkURL {
                row("store") {
                    Button { openURL(url) } label: {
                        Label(host, systemImage: "arrow.up.right")
                            .labelStyle(TrailingIconLabelStyle())
                    }
                    .foregroundStyle(Color.swBlue)
                }
            }
            if item.colorName != nil || item.colorHex != nil {
                row("colour") {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(item.colorHex.map { Color(hex: $0) } ?? Color.swMuted)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().strokeBorder(.black.opacity(0.1)))
                        Text(item.colorName ?? "")
                    }
                }
            }
            row("saved") {
                Text(item.createdAt, format: .dateTime.month().day())
            }
        }
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title).foregroundStyle(Color.swMuted)
            Spacer(minLength: 12)
            content()
                .foregroundStyle(Color.swInk)
                .lineLimit(1)
        }
        .font(SWTextStyle.body.font).tracking(SWTextStyle.body.tracking)
        .frame(minHeight: 28)
    }
}

// MARK: - Settings sheet

struct ShelfSettingsSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @Query(filter: #Predicate<SavedItem> { $0.statusRaw == "cooling" })
    private var cooling: [SavedItem]

    @State private var days = ShelfSettings.coolingDays
    @State private var reminderStatus: UNAuthorizationStatus = .notDetermined

    private var options: [Int] {
        ShelfSettings.dayOptions.contains(days) ? ShelfSettings.dayOptions : (ShelfSettings.dayOptions + [days]).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("waiting period")
                    .swText(.title)
                Text("how long new saves rest before you decide")
                    .swText(.caption, color: .swMuted)
            }

            // Chips, like the wishlist's category filters
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isOn = option == days
                    Button { days = option } label: {
                        Text("\(option) \(option == 1 ? "day" : "days")")
                            .swText(.caption, color: isOn ? .swPaper : .swInk)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isOn ? Color.swInk : Color.white, in: Capsule())
                            .overlay(Capsule().stroke(Color.swLine, lineWidth: isOn ? 0 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: days)

            Text("changes apply to everything still cooling, too.")
                .swText(.caption, color: .swMuted)

            ShelfSectionCard(label: "REMINDERS") {
                HStack {
                    Text(reminderText)
                        .swText(.body)
                    Spacer()
                    reminderButton
                }
            }

            Spacer(minLength: 0)

            Button("done") { dismiss() }
                .buttonStyle(SWPrimaryButtonStyle())
        }
        .padding(20)
        .padding(.top, 8)
        .background(Color.swPaper.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .task { reminderStatus = await ShelfNotifications.authorizationStatus() }
        .onChange(of: days) { _, newValue in
            ShelfSettings.coolingDays = newValue
            cooling.forEach { $0.applyCoolingPeriod(ShelfSettings.coolingPeriod) }
            try? context.save()
        }
    }

    private var reminderText: String {
        switch reminderStatus {
        case .authorized, .provisional, .ephemeral: "on — we'll nudge you when something's ready"
        case .denied: "off — turn them on in Settings"
        default: "off"
        }
    }

    @ViewBuilder
    private var reminderButton: some View {
        switch reminderStatus {
        case .notDetermined:
            Button("turn on") {
                Task {
                    await ShelfNotifications.requestPermission()
                    reminderStatus = await ShelfNotifications.authorizationStatus()
                }
            }
            .swText(.bodyStrong, color: .swBlue)
        case .denied:
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .swText(.bodyStrong, color: .swBlue)
        default:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.swBlue)
        }
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) { configuration.title; configuration.icon }
    }
}

// --- previews

#Preview("Shelf") {
    ShelfView()
        .modelContainer(ShelfDebug.previewContainer)
}
