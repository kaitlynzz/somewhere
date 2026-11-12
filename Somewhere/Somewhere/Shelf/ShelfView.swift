//
//  ShelfView.swift
//  Somewhere — Cooling shelf (Kaitlyn)
//
//  The shelf tab:
//  • top: swipe cards for saves whose cooling period is over
//  • bottom: the "still cooling" shelf, with time left on each save
//  • tap a cooling save to add a note / voice note on why you wanted it
//  • toolbar: change the waiting period and turn on reminders
//
//  Styled like Nicole's wishlist (Theme.swift) so the two tabs match.
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

                VStack(spacing: 0) {
                    header(readyCount: ready.count)

                    if ready.isEmpty {
                        emptyState(next: waiting.first)
                            .frame(maxHeight: .infinity)
                    } else {
                        ShelfDeck(items: ready, onDecide: decide)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            .padding(.bottom, 20)   // room for the cards stacked behind
                            .frame(maxHeight: .infinity)
                        swipeHint
                    }

                    if reminderStatus == .notDetermined && !cooling.isEmpty {
                        reminderPrompt
                    }

                    if !waiting.isEmpty {
                        coolingShelf(waiting, now: now)
                    }
                }
            }
            .background(Theme.cream.ignoresSafeArea())
            .overlay(alignment: .bottom) { toastView }
        }
        .tint(Theme.blue)
        .sensoryFeedback(trigger: toast) { _, new in
            new.map { $0.keep ? .success : .impact(weight: .light) }
        }
        .sheet(item: $selected) { item in
            CoolingItemSheet(item: item) { decide(item, keep: false) }
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            coolingDays = ShelfSettings.coolingDays
            Task { reminderStatus = await ShelfNotifications.authorizationStatus() }
        }) {
            ShelfSettingsSheet()
        }
        .task { reminderStatus = await ShelfNotifications.authorizationStatus() }
    }

    // MARK: Header + toolbar

    private func header(readyCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            topButtons
            Text("the cooling shelf")
                .font(Theme.display(38))
                .foregroundStyle(Theme.headlineGradient)
            Text(readyCount > 0
                 ? "\(readyCount) \(readyCount == 1 ? "thing has" : "things have") cooled off"
                 : "things rest here for \(coolingDays) \(coolingDays == 1 ? "day" : "days") before you decide")
                .font(Theme.body(14))
                .foregroundStyle(Theme.inkSoft)
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
            .foregroundStyle(Theme.blue)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(.ultraThinMaterial, in: Capsule())
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
        .font(Theme.body(12, weight: .medium))
        .foregroundStyle(Theme.inkSoft.opacity(0.8))
        .padding(.bottom, 12)
        .accessibilityHidden(true)
    }

    // MARK: Empty

    private func emptyState(next: SavedItem?) -> some View {
        VStack(spacing: 14) {
            Image(systemName: next == nil ? "sparkles" : "moon.zzz")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.periwinkle)
            Text(next == nil ? "nothing cooling yet" : "nothing to decide yet")
                .font(Theme.display(22))
                .foregroundStyle(Theme.headlineGradient)
                .multilineTextAlignment(.center)
            Group {
                if let next {
                    Text("next one's ready \(next.shelfReadyAt, format: .relative(presentation: .named)).")
                } else {
                    Text("New saves rest here for a few days, so impulse buys have time to fade.")
                }
            }
            .font(Theme.body(14))
            .foregroundStyle(Theme.inkSoft)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    // MARK: Reminders

    private var reminderPrompt: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.pink)
            Text("get a nudge when something's ready")
                .font(Theme.body(14, weight: .medium))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            Button("turn on") {
                Task {
                    await ShelfNotifications.requestPermission()
                    reminderStatus = await ShelfNotifications.authorizationStatus()
                    await ShelfNotifications.sync(cooling.map(ShelfNotifications.Reminder.init))
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Theme.ink, in: Capsule())
        }
        .padding(14)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.ink.opacity(0.05)))
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: Still cooling

    private func coolingShelf(_ items: [SavedItem], now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("STILL COOLING")
                    .font(Theme.label)
                    .foregroundStyle(Theme.blue)
                Text("\(items.count)")
                    .font(Theme.label)
                    .foregroundStyle(Theme.inkSoft)
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
        .background(Theme.lavender.opacity(0.7))
    }

    // MARK: Decide + undo

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
                    .font(Theme.body(15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Button("undo") { undo(toast) }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.yellow)
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .background(Theme.ink, in: Capsule())
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

// MARK: - Cooling tile

/// A small polaroid on the "still cooling" shelf — same look as a wishlist card.
struct CoolingTile: View {
    let item: SavedItem
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .frame(width: 96, height: 96)
                .overlay { ItemImageView(item: item, maxPixel: 500) }
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(alignment: .topLeading) {
                    ShelfTimeBadge(text: timeLeft).padding(5)
                }
                .overlay(alignment: .bottomTrailing) {
                    if item.voiceNoteURL != nil {
                        Image(systemName: "waveform")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(Theme.pink, in: Circle())
                            .padding(5)
                    }
                }

            Text(item.title)
                .font(Theme.hand(14))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .frame(width: 96, alignment: .leading)
        }
        .padding(7)
        .padding(.bottom, 2)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 5)
        .rotationEffect(.degrees(item.tiltDegrees))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(timeLeft)")
        .accessibilityHint("Add a note on why you want it")
    }

    private var timeLeft: String {
        let seconds = item.shelfReadyAt.timeIntervalSince(now)
        if seconds >= 82_800 {   // 23h+ reads as "1 day left"
            let days = Int((seconds / 86_400).rounded(.up))
            return "\(days) \(days == 1 ? "day" : "days") left"
        }
        if seconds >= 3_600 { return "\(Int((seconds / 3_600).rounded(.up)))h left" }
        return "almost ready"
    }
}

// MARK: - Section card (same look as the wishlist's item page)

struct ShelfSectionCard<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(Theme.label)
                .foregroundStyle(Theme.blue)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.ink.opacity(0.05)))
    }
}

// MARK: - Cooling item sheet

/// "why I wanted it" — note + voice note for a save that's still cooling.
struct CoolingItemSheet: View {
    let item: SavedItem
    var onLetGo: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Polaroid
                VStack(spacing: 12) {
                    ItemImageView(item: item, maxPixel: 1200)
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    Text(item.title)
                        .font(Theme.hand(20))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .padding(.bottom, 6)
                }
                .padding(12)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
                .rotationEffect(.degrees(item.tiltDegrees))
                .padding(.horizontal, 6)

                ShelfSectionCard(label: "THE COOLING SHELF") {
                    HStack(spacing: 10) {
                        ShelfTimeBadge(text: "cooling")
                        Text("ready \(item.shelfReadyAt, format: .dateTime.weekday(.wide).hour().minute())")
                            .font(Theme.body(15, weight: .medium))
                            .foregroundStyle(Theme.ink)
                    }

                    Divider().overlay(Theme.ink.opacity(0.05))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("why I wanted it")
                            .font(Theme.hand(17))
                            .foregroundStyle(Theme.pink)

                        TextField("wore it to… / perfect for… / because…", text: noteBinding, axis: .vertical)
                            .font(Theme.body(15))
                            .lineLimit(2...6)
                            .padding(12)
                            .background(Theme.yellow.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))

                        VoiceNoteRecorderView(item: item)
                    }
                }

                Button {
                    dismiss()
                    onLetGo()
                } label: {
                    Text("let go now")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Theme.paper, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.cream.ignoresSafeArea())
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
                    .font(Theme.display(30))
                    .foregroundStyle(Theme.headlineGradient)
                Text("how long new saves rest before you decide")
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.inkSoft)
            }

            // Chips, like the wishlist's category filters
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isOn = option == days
                    Button { days = option } label: {
                        Text("\(option) \(option == 1 ? "day" : "days")")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isOn ? .white : Theme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isOn ? AnyShapeStyle(Theme.pink) : AnyShapeStyle(Theme.paper), in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.ink.opacity(isOn ? 0 : 0.08)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: days)

            Text("changes apply to everything still cooling, too.")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)

            ShelfSectionCard(label: "REMINDERS") {
                HStack {
                    Text(reminderText)
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    reminderButton
                }
            }

            Spacer(minLength: 0)

            Button { dismiss() } label: {
                Text("done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.ink, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .padding(.top, 8)
        .background(Theme.cream.ignoresSafeArea())
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
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.blue)
        case .denied:
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.blue)
        default:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
        }
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) { configuration.title; configuration.icon }
    }
}

// MARK: - Previews

#Preview("Shelf") {
    ShelfView()
        .modelContainer(ShelfDebug.previewContainer)
}
