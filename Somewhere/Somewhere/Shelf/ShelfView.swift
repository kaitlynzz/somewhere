//
//  ShelfView.swift
//  Somewhere — Cooling shelf (Kaitlyn)
//
//  The shelf tab:
//  • top: swipe cards for saves whose cooling period is over
//  • bottom: the "still cooling" shelf, with time left on each save
//  • tap a cooling save to add a note / voice note on why you wanted it
//  • gear: change the waiting period and turn on reminders
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
        // Re-checks every minute so cards appear the moment they're ready.
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let now = timeline.date
            let ready = cooling.filter { $0.shelfReadyAt <= now }
            let waiting = cooling.filter { $0.shelfReadyAt > now }

            VStack(spacing: 0) {
                header(readyCount: ready.count)

                if ready.isEmpty {
                    emptyState(next: waiting.first, now: now)
                        .frame(maxHeight: .infinity)
                } else {
                    ShelfDeck(items: ready, onDecide: decide)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
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
        .background(Color.swPaper.ignoresSafeArea())
        .overlay(alignment: .bottom) { toastView }
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

    // MARK: Header

    private func header(readyCount: Int) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("the cooling shelf.")
                    .swText(.title)
                Text(readyCount > 0
                     ? "\(readyCount) \(readyCount == 1 ? "save has" : "saves have") cooled off."
                     : "saves rest for \(coolingDays) \(coolingDays == 1 ? "day" : "days") before you decide.")
                    .swText(.body, color: .swMuted)
            }
            Spacer(minLength: 12)

            #if DEBUG
            Menu {
                Button("reset to demo items", systemImage: "sparkles") { ShelfDebug.resetToDemo(in: context) }
                Button("add test saves", systemImage: "plus") { ShelfDebug.addTestItems(in: context) }
                Button("make everything ready now", systemImage: "forward.end") { ShelfDebug.makeAllReady(in: context) }
            } label: {
                Image(systemName: "ladybug")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.swMuted)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Debug tools")
            #endif

            Button { showSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.swInk)
                    .frame(width: 36, height: 36)
                    .background(Color.white, in: Circle())
                    .overlay(Circle().stroke(Color.swLine, lineWidth: 1))
            }
            .accessibilityLabel("Shelf settings")
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var swipeHint: some View {
        HStack(spacing: 20) {
            Label("let go", systemImage: "arrow.left")
            Label { Text("keep it") } icon: { Image(systemName: "arrow.right") }
                .labelStyle(TrailingIconLabelStyle())
        }
        .font(.custom("Inter-Medium", size: 12))
        .foregroundStyle(Color.swMuted.opacity(0.8))
        .padding(.vertical, 12)
        .accessibilityHidden(true)
    }

    // MARK: Empty

    private func emptyState(next: SavedItem?, now: Date) -> some View {
        VStack(spacing: 14) {
            AsteriskMark(size: 34)
                .frame(width: 72, height: 72)
                .background(Color.swSky, in: Circle())

            Text(next == nil ? "your shelf is empty." : "nothing to decide yet.")
                .swText(.headline)

            Group {
                if let next {
                    Text("next one's ready \(next.shelfReadyAt, format: .relative(presentation: .named)).")
                } else {
                    Text("new saves rest here for a few days,\nso impulse buys have time to fade.")
                }
            }
            .swText(.body, color: .swMuted)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    // MARK: Reminders

    private var reminderPrompt: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.swBlue)
            Text("get a nudge when a save is ready.")
                .swText(.bodyStrong)
            Spacer(minLength: 8)
            Button("turn on") {
                Task {
                    await ShelfNotifications.requestPermission()
                    reminderStatus = await ShelfNotifications.authorizationStatus()
                    await ShelfNotifications.sync(cooling.map(ShelfNotifications.Reminder.init))
                }
            }
            .font(.custom("Inter-SemiBold", size: 14))
            .foregroundStyle(Color.swPaper)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Color.swInk, in: Capsule())
        }
        .padding(14)
        .background(Color.swBlue50, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    // MARK: Still cooling

    private func coolingShelf(_ items: [SavedItem], now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("STILL COOLING")
                    .swText(.label, color: .swMuted)
                Text("\(items.count)")
                    .swText(.label, color: .swBlue)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(items) { item in
                        Button { selected = item } label: {
                            CoolingTile(item: item, now: now)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }
        }
        .background(Color.swSurfaceSunk)
        .overlay(alignment: .top) { Rectangle().fill(Color.swLine).frame(height: 1) }
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
                    .font(.custom("Inter-SemiBold", size: 15))
                    .foregroundStyle(Color.swPaper)
                Spacer(minLength: 8)
                Button("undo") { undo(toast) }
                    .font(.custom("Inter-Bold", size: 15))
                    .foregroundStyle(Color.swSky)
            }
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(Color.swInk, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 24)
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

/// A small polaroid on the "still cooling" shelf, with a "2 days left" sticker.
struct CoolingTile: View {
    let item: SavedItem
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .frame(width: 104, height: 104)
                .overlay { ItemImageView(item: item, maxPixel: 320) }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if item.voiceNoteURL != nil {
                        Image(systemName: "waveform")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.swInk)
                            .padding(5)
                            .background(Color.swStickerPink, in: Circle())
                            .padding(5)
                    }
                }

            Text(item.title)
                .font(.custom("Inter-Medium", size: 12))
                .foregroundStyle(Color.swInk)
                .lineLimit(1)
                .frame(width: 104, alignment: .leading)
        }
        .padding(7)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        .rotationEffect(.degrees(item.tiltDegrees))
        .overlay(alignment: .topTrailing) {
            SWSticker(text: timeLeft, color: .swStickerButter, tilt: 6)
                .offset(x: 10, y: -10)
        }
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

// MARK: - Cooling item sheet

/// "why did you want it?" — note + voice note for a save that's still cooling.
struct CoolingItemSheet: View {
    let item: SavedItem
    var onLetGo: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Color.clear
                    .frame(height: 260)
                    .frame(maxWidth: .infinity)
                    .overlay { ItemImageView(item: item, maxPixel: 900) }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .swText(.title)
                        .lineLimit(3)
                    HStack(spacing: 8) {
                        SWSticker(text: "cooling", color: .swStickerButter, tilt: -3)
                        Text("ready \(item.shelfReadyAt, format: .dateTime.weekday(.wide).hour().minute())")
                            .swText(.caption, color: .swMuted)
                    }
                }

                Rectangle().fill(Color.swLine).frame(height: 1)

                VStack(alignment: .leading, spacing: 12) {
                    Text("WHY DID YOU WANT IT?")
                        .swText(.label, color: .swMuted)

                    TextField("a quick note for future you…", text: noteBinding, axis: .vertical)
                        .font(.custom("Inter-Regular", size: 16))
                        .lineLimit(2...5)
                        .padding(14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.swLine, lineWidth: 1))

                    VoiceNoteRecorderView(item: item)
                }

                Rectangle().fill(Color.swLine).frame(height: 1)

                Button("let go now") {
                    dismiss()
                    onLetGo()
                }
                .buttonStyle(SWChoiceButtonStyle(kind: .light))
            }
            .padding(24)
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
            VStack(alignment: .leading, spacing: 6) {
                Text("waiting period.")
                    .swText(.title)
                Text("how long new saves rest before you decide.")
                    .swText(.body, color: .swMuted)
            }

            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button { days = option } label: {
                        Text("\(option)d")
                            .font(.custom("Inter-SemiBold", size: 15))
                            .foregroundStyle(option == days ? Color.swPaper : Color.swInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(option == days ? Color.swInk : Color.white,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(option == days ? Color.clear : Color.swLine, lineWidth: 1))
                    }
                    .accessibilityLabel("\(option) \(option == 1 ? "day" : "days")")
                    .accessibilityAddTraits(option == days ? .isSelected : [])
                }
            }

            Text("changes apply to everything still cooling, too.")
                .swText(.caption, color: .swMuted)

            Rectangle().fill(Color.swLine).frame(height: 1)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("reminders").swText(.bodyStrong)
                    Text(reminderText).swText(.caption, color: .swMuted)
                }
                Spacer()
                reminderButton
            }

            Spacer(minLength: 0)

            Button("done") { dismiss() }
                .buttonStyle(SWPrimaryButtonStyle())
        }
        .padding(24)
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
        case .authorized, .provisional, .ephemeral: "on. we'll nudge you when a save is ready."
        case .denied: "off. turn them on in Settings."
        default: "off."
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
            .font(.custom("Inter-SemiBold", size: 14))
            .foregroundStyle(Color.swBlue)
        case .denied:
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .font(.custom("Inter-SemiBold", size: 14))
            .foregroundStyle(Color.swBlue)
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

// MARK: - Previews

#Preview("Shelf") {
    ShelfView()
        .modelContainer(ShelfDebug.previewContainer)
}
