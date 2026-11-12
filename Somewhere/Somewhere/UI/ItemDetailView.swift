//
//  ItemDetailView.swift
//  Somewhere — the "context" page for one saved item:
//  what it is, where & when you saw it, why you wanted it, and what to do next.
//

import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Bindable var item: SavedItem

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var confirmDelete = false
    @State private var showFoundText = false
    @FocusState private var noteFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                polaroid
                titleBlock
                if let url = item.linkURL { linkButton(url) }
                storySection
                detailsSection
                if let text = item.recognizedText, !text.isEmpty { foundTextSection(text) }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.cream.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.cream, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let url = item.linkURL {
                    ShareLink(item: url)
                }
                Menu {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { noteFocused = false }
            }
        }
        .confirmationDialog("Delete this item?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                ThumbnailCache.shared.invalidate(item.id)
                SavedItemStore.delete(item, in: context)
                dismiss()
            }
        } message: {
            Text("This removes it from somewhere for good.")
        }
    }

    // MARK: - Photo

    private var polaroid: some View {
        VStack(spacing: 12) {
            ItemImageView(item: item, maxPixel: 1200)
                .frame(maxWidth: .infinity)
                .frame(height: 340)
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
    }

    // MARK: - Name, brand, price

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("give it a name", text: $item.title, axis: .vertical)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.ink)

            let meta = [item.brand, item.price].compactMap { $0 }.filter { !$0.isEmpty }
            if !meta.isEmpty {
                Text(meta.joined(separator: " · "))
                    .font(Theme.body(15, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private func linkButton(_ url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Image(systemName: "bag")
                Text("go to \(item.linkHost ?? "link")")
                    .lineLimit(1)
                Spacer()
                Image(systemName: "arrow.up.right")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(Theme.ink, in: Capsule())
        }
    }

    // MARK: - The story: where, when, why

    private var storySection: some View {
        SectionCard(label: "THE STORY") {
            // Where + when
            HStack(alignment: .center, spacing: 10) {
                SourceChip(source: item.sourceApp)
                VStack(alignment: .leading, spacing: 1) {
                    Text("saved \(item.createdAt, format: .relative(presentation: .named))")
                        .font(Theme.body(15, weight: .medium))
                    Text(item.createdAt, format: .dateTime.weekday(.wide).month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }

            Divider().overlay(Theme.ink.opacity(0.05))

            // Why
            VStack(alignment: .leading, spacing: 8) {
                Text("why I wanted it")
                    .font(Theme.hand(17))
                    .foregroundStyle(Theme.pink)

                TextField("wore it to… / perfect for… / because…", text: noteBinding, axis: .vertical)
                    .font(Theme.body(15))
                    .lineLimit(2...6)
                    .focused($noteFocused)
                    .padding(12)
                    .background(Theme.yellow.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))

                if let url = item.voiceNoteURL {
                    VoiceNoteRow(url: url)
                }
            }
        }
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { item.note ?? "" },
            set: { item.note = $0.isEmpty ? nil : $0 }
        )
    }

    // MARK: - Details: category, colour, shelf

    private var detailsSection: some View {
        SectionCard(label: "DETAILS") {
            row("category") {
                Picker("category", selection: $item.category) {
                    ForEach(ItemCategory.allCases) { category in
                        Label(category.displayName, systemImage: category.symbol).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.ink)
            }

            if item.colorName != nil || item.colorHex != nil {
                row("colour") {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(item.colorHex.map { Color(hex: $0) } ?? Theme.inkSoft)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().strokeBorder(.black.opacity(0.1)))
                        Text(item.colorName ?? "")
                            .font(Theme.body(15))
                    }
                }
            }

            row("shelf") {
                Text(shelfText)
                    .font(Theme.body(15))
                    .foregroundStyle(item.isCooling ? Theme.blue : Theme.green)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var shelfText: String {
        switch item.status {
        case .cooling where item.isReadyToDecide:
            return "ready to decide"
        case .cooling:
            let ready = item.shelfReadyAt.formatted(.relative(presentation: .named))
            return "cooling · ready \(ready)"
        case .kept:
            let day = (item.decidedAt ?? item.createdAt).formatted(.dateTime.month().day())
            return "kept it · \(day)"
        case .letGo:
            return "let it go"
        }
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(Theme.body(15))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            content()
        }
        .frame(minHeight: 32)
    }

    // MARK: - Text found in screenshot

    private func foundTextSection(_ text: String) -> some View {
        SectionCard(label: "TEXT IN THE SCREENSHOT") {
            Text(text)
                .font(Theme.body(14))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(showFoundText ? nil : 3)
                .textSelection(.enabled)
            Button(showFoundText ? "show less" : "show all") {
                withAnimation(.snappy) { showFoundText.toggle() }
            }
            .font(.system(size: 13, weight: .semibold))
        }
    }
}

// MARK: - Section card

private struct SectionCard<Content: View>: View {
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

// MARK: - Preview

#Preview {
    let container = SampleData.previewContainer
    let item = try! container.mainContext.fetch(FetchDescriptor<SavedItem>()).first!
    return NavigationStack { ItemDetailView(item: item) }
        .modelContainer(container)
}
