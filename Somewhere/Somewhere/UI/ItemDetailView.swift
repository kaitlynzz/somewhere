//
//  ItemDetailView.swift
//  Somewhere — the "context" page for one saved item:
//  what it is, where & when you saw it, why you wanted it, and what to do next.
//  Updated to use DesignSystem.swift (Muskaan).
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
        .background(Color.swPaper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.swPaper, for: .navigationBar)
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

    // --- photo

    private var polaroid: some View {
        VStack(spacing: 12) {
            ItemImageView(item: item, maxPixel: 1200)
                .frame(maxWidth: .infinity)
                .frame(height: 340)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

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
    }

    // --- name, brand, price

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("give it a name", text: $item.title, axis: .vertical)
                .swText(.title)

            let meta = [item.brand, item.price].compactMap { $0 }.filter { !$0.isEmpty }
            if !meta.isEmpty {
                Text(meta.joined(separator: " · "))
                    .swText(.caption, color: .swMuted)
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
            .swText(.bodyStrong, color: .white)
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(Color.swInk, in: Capsule())
        }
    }

    // --- the story: where, when, why

    private var storySection: some View {
        SectionCard(label: "THE STORY") {
            // Where + when
            HStack(alignment: .center, spacing: 10) {
                SourceChip(source: item.sourceApp)
                VStack(alignment: .leading, spacing: 1) {
                    Text("saved \(item.createdAt, format: .relative(presentation: .named))")
                        .swText(.bodyStrong)
                    Text(item.createdAt, format: .dateTime.weekday(.wide).month().day().hour().minute())
                        .swText(.chip, color: .swMuted)
                }
            }

            Divider().overlay(Color.swLine)

            // Why
            VStack(alignment: .leading, spacing: 8) {
                Text("why I wanted it")
                    .swText(.bodyStrong, color: .swBlue)

                TextField("wore it to… / perfect for… / because…", text: noteBinding, axis: .vertical)
                    .swText(.voice)
                    .lineLimit(2...6)
                    .focused($noteFocused)
                    .padding(12)
                    .background(Color.swStickerButter.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

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

    // --- details: category, colour, shelf

    private var detailsSection: some View {
        SectionCard(label: "DETAILS") {
            row("category") {
                Picker("category", selection: $item.category) {
                    ForEach(ItemCategory.allCases) { category in
                        Label(category.displayName, systemImage: category.symbol).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.swInk)
            }

            if let type = item.itemType {
                row("what it is") {   // ItemKind: more specific than the category
                    Text(type)
                        .swText(.body)
                }
            }

            if item.colorName != nil || item.colorHex != nil {
                row("colour") {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(item.colorHex.map { Color(hex: $0) } ?? Color.swMuted)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().strokeBorder(Color.swLine))
                        Text(item.colorName ?? "")
                            .swText(.body)
                    }
                }
            }

            if let tags = item.visualTags, !tags.isEmpty {
                // What Vision saw in the picture (VisualTagger) — the words search can use.
                row("looks like") {
                    Text(tags.split(separator: " ").prefix(4)
                        .map { $0.replacingOccurrences(of: "_", with: " ") }
                        .joined(separator: ", "))
                        .swText(.body)
                        .multilineTextAlignment(.trailing)
                }
            }

            row("shelf") {
                Text(shelfText)
                    .swText(.body, color: item.isCooling ? .swBlue : .swInk)
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
                .swText(.body, color: .swMuted)
            Spacer()
            content()
        }
        .frame(minHeight: 32)
    }

    // --- text found in screenshot

    private func foundTextSection(_ text: String) -> some View {
        SectionCard(label: "TEXT IN THE SCREENSHOT") {
            Text(text)
                .swText(.caption, color: .swMuted)
                .lineLimit(showFoundText ? nil : 3)
                .textSelection(.enabled)
            Button(showFoundText ? "show less" : "show all") {
                withAnimation(.snappy) { showFoundText.toggle() }
            }
            .swText(.caption, color: .swBlue)
        }
    }
}

// --- section card

private struct SectionCard<Content: View>: View {
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

// --- preview

#Preview {
    let container = SampleData.previewContainer
    let item = try! container.mainContext.fetch(FetchDescriptor<SavedItem>()).first!
    return NavigationStack { ItemDetailView(item: item) }
        .modelContainer(container)
}
