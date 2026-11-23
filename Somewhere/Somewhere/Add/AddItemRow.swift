//
//  AddItemRow.swift
//  Somewhere — one thing in the add sheet, laid out like a shopping-cart line:
//  picture, name, where it's from, price, and "why do you want it?" right
//  underneath. Every detail is editable in place.
//
//  Used for "add one" (the whole form is this row) and for each result after
//  "add all to wishlist". While its link is being read it shows a placeholder.
//
//  App target only.
//

import SwiftUI

struct AddItemRow: View {
    @Bindable var draft: AddDraft
    /// Shows a remove button (the results list). nil hides it.
    var onRemove: (() -> Void)?

    @FocusState private var focus: Field?
    private enum Field { case name, reason }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    nameField
                    if let price = draft.metadata?.price {
                        Text(price)
                            .swText(.bodyStrong)
                            .fixedSize()
                    }
                }

                fromLine

                reasonField
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.swLine, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) { removeButton }
        .animation(.easeOut(duration: 0.25), value: draft.lookup)
    }

    // MARK: Pieces

    private var thumbnail: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.swPaper)
            .frame(width: 72, height: 90)
            .overlay {
                if let image = draft.previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else if draft.isLooking {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: draft.category.symbol)
                        .font(.system(size: 22))
                        .foregroundStyle(Color.swMuted.opacity(0.4))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var nameField: some View {
        if draft.isLooking && draft.title.isEmpty {
            Text("reading \(draft.host ?? "the page")…")
                .swText(.bodyStrong, color: Color.swMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            TextField(draft.savedItem == nil ? "what is it?" : "name it", text: $draft.title, axis: .vertical)
                .font(SWTextStyle.bodyStrong.font).tracking(SWTextStyle.bodyStrong.tracking)
                .lineLimit(1...3)
                .focused($focus, equals: .name)
                .submitLabel(.next)
                .onSubmit { focus = .reason }
                .padding(.trailing, onRemove == nil ? 0 : 22)   // room for the ✕
        }
    }

    private var fromLine: some View {
        HStack(spacing: 6) {
            Image(systemName: draft.source.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(draft.source.labelTint)
            Text(fromText)
                .swText(.caption, color: draft.lookupError == nil ? Color.swMuted : Color.swError)
                .lineLimit(1)

            Spacer(minLength: 4)

            categoryMenu
        }
    }

    private var fromText: String {
        if draft.lookupError != nil { return "couldn't read \(draft.host ?? "the page")" }
        if let store = draft.storeName { return "from \(store)" }
        return draft.hasText ? "not a link yet" : "no link — that's fine"
    }

    private var categoryMenu: some View {
        Menu {
            Picker("category", selection: $draft.categoryOverride) {
                Text("pick for me (\(draft.guessedCategory.displayName))").tag(ItemCategory?.none)
                ForEach(ItemCategory.allCases) { category in
                    Label(category.displayName, systemImage: category.symbol).tag(Optional(category))
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(draft.category.displayName)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
            }
            .swText(.chip, color: Color.swBlue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.swBlue.opacity(0.1), in: Capsule())
        }
        .accessibilityLabel("Category: \(draft.category.displayName)")
    }

    private var reasonField: some View {
        TextField("why do you want it? (optional)", text: $draft.note, axis: .vertical)
            .font(SWTextStyle.caption.font).tracking(SWTextStyle.caption.tracking)
            .lineLimit(1...4)
            .focused($focus, equals: .reason)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.swPaper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var removeButton: some View {
        if let onRemove {
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.swMuted)
                    .frame(width: 22, height: 22)
                    .background(Color.swPaper, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel("Remove \(draft.title.isEmpty ? "this" : draft.title)")
        }
    }
}
