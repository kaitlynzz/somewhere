//
//  AddItemView.swift
//  Somewhere — Add (Karan)
//
//  Karan: the in-app "+" screen.
//
//  Two ways to put something on your wishlist without leaving the app:
//  paste a link and let the page fill itself in, or just type a name.
//  Saves through SavedItemStore, same as the Share Extension, so everything
//  lands in the one shared store.
//
//  App target only.
//

import SwiftUI
import SwiftData

struct AddItemView: View {

    @Environment(\.modelContext) private var context
    @State private var model = AddItemModel()
    @FocusState private var focus: Field?

    private enum Field { case link, title, note }

    // MARK: Readable slices of the model's state

    private var savedSummary: (title: String, coolingDays: Int)? {
        if case .saved(let title, let days) = model.saveState { return (title, days) }
        return nil
    }
    private var saveError: String? {
        if case .failed(let message) = model.saveState { return message }
        return nil
    }
    private var lookupError: String? {
        if case .failed(let message) = model.lookupState { return message }
        return nil
    }
    private var isLookingUp: Bool { model.lookupState == .looking }
    private var isSaving: Bool { model.saveState == .saving }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if let saved = savedSummary {
                        savedCard(title: saved.title, days: saved.coolingDays)
                    } else {
                        linkCard
                        if model.metadata != nil || model.previewImage != nil { previewCard }
                        detailsCard
                        if let saveError { helper(saveError, tint: .red) }
                        saveButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Theme.cream.ignoresSafeArea())
            .toolbarBackground(Theme.cream, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Theme.blue)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("add something")
                .font(Theme.display(34))
                .foregroundStyle(Theme.headlineGradient)
            Text("paste a link, or just type it")
                .font(Theme.body(14))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.top, 8)
    }

    // MARK: Link

    private var linkCard: some View {
        card {
            Text("THE LINK").font(Theme.label).foregroundStyle(Theme.inkSoft)

            HStack(spacing: 10) {
                TextField("paste a link…", text: $model.linkText)
                    .textFieldStyle(.plain)
                    .font(Theme.body(15))
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .focused($focus, equals: .link)
                    .onSubmit { focus = nil; Task { await model.lookUp() } }

                if isLookingUp {
                    ProgressView().controlSize(.small)
                } else if !model.linkText.isEmpty {
                    Button { model.clearLink() } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.inkSoft.opacity(0.45))
                    .accessibilityLabel("Clear the link")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let lookupError {
                helper(lookupError, tint: .red)
            } else if model.metadata != nil {
                helper("got it — check the details below", tint: Theme.green)
            } else {
                helper("from a shop, a blog, anywhere with a product page", tint: Theme.inkSoft)
            }

            Button {
                focus = nil
                Task { await model.lookUp() }
            } label: {
                Label(isLookingUp ? "looking…" : "look it up", systemImage: "magnifyingglass")
                    .font(Theme.body(14, weight: .medium))
            }
            .disabled(model.parsedLink == nil || isLookingUp)
        }
    }

    private var previewCard: some View {
        card {
            Text("WHAT I FOUND").font(Theme.label).foregroundStyle(Theme.inkSoft)

            HStack(alignment: .top, spacing: 14) {
                if let image = model.previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 74, height: 94)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .rotationEffect(.degrees(-1.2))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(model.metadata?.title ?? model.title)
                        .font(Theme.body(15, weight: .medium))
                        .lineLimit(3)

                    if let brand = model.metadata?.brand {
                        Text(brand).font(Theme.body(13)).foregroundStyle(Theme.inkSoft)
                    }
                    if let price = model.metadata?.price {
                        Text(price).font(Theme.body(14, weight: .medium)).foregroundStyle(Theme.pink)
                    }

                    Label(model.source.displayName, systemImage: model.source.symbol)
                        .font(Theme.body(12))
                        .foregroundStyle(model.source.tint)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Details

    private var detailsCard: some View {
        card {
            Text("DETAILS").font(Theme.label).foregroundStyle(Theme.inkSoft)

            field("what is it?") {
                TextField("the perfect shoes", text: $model.title)
                    .focused($focus, equals: .title)
                    .submitLabel(.next)
            }

            field("why do you want it?") {
                TextField("optional — future you will thank you",
                          text: $model.note, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focus, equals: .note)
            }

            Picker(selection: $model.categoryOverride) {
                Text("pick for me (\(model.guessedCategory.displayName))").tag(ItemCategory?.none)
                ForEach(ItemCategory.allCases) { category in
                    Label(category.displayName, systemImage: category.symbol)
                        .tag(Optional(category))
                }
            } label: {
                Text("category").font(Theme.body(14))
            }
            .pickerStyle(.menu)
            .tint(Theme.blue)
        }
    }

    // MARK: Save

    private var saveButton: some View {
        Button {
            focus = nil
            model.save(in: context)
        } label: {
            HStack(spacing: 8) {
                if isSaving { ProgressView().controlSize(.small).tint(.white) }
                Text(isSaving ? "saving…" : "save to somewhere")
                    .font(Theme.body(16, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(model.canSave ? Theme.blue : Theme.inkSoft.opacity(0.25), in: Capsule())
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(!model.canSave)
        .padding(.top, 2)
    }

    private func savedCard(title: String, days: Int) -> some View {
        card {
            Label("saved", systemImage: "checkmark.circle.fill")
                .font(Theme.body(16, weight: .medium))
                .foregroundStyle(Theme.green)

            Text("\u{201C}\(title)\u{201D} is resting on your shelf for \(days) \(days == 1 ? "day" : "days").")
                .font(Theme.body(15))

            Text("that's why it isn't in your wishlist yet — when the time's up you'll decide to keep it or let it go.")
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSoft)

            HStack(spacing: 12) {
                Button {
                    model.reset()
                    AppRouter.shared.selectedTab = .shelf
                } label: {
                    Label("go to the shelf", systemImage: "hourglass")
                }
                Button("add another") { model.reset() }
            }
            .font(Theme.body(14, weight: .medium))
            .padding(.top, 2)
        }
    }

    // MARK: Small pieces

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
            )
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(Theme.body(13)).foregroundStyle(Theme.inkSoft)
            content()
                .textFieldStyle(.plain)
                .font(Theme.body(15))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func helper(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(Theme.body(12))
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Preview

#Preview("Add") {
    AddItemView()
        .modelContainer(SampleData.previewContainer)
}
