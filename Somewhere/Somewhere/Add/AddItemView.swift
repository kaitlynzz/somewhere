//
//  AddItemView.swift
//  Somewhere — Add (Karan)
//
//  The in-app "+" screen. Opens as a bottom sheet from the raised "+" in the
//  tab bar (SomewhereTabBar). Swipe the sheet down to close it.
//
//  • add one: paste a link (it reads the page by itself) or type a name. The
//    whole form is one cart-style row (AddItemRow). Saving plays the success
//    animation (SaveSuccessView).
//  • add multiple: a Reminders-style list — type or paste links, Return for
//    the next one, paste a whole list and it splits into rows. "add all to
//    wishlist" scans and saves them all, then shows them as cart rows where
//    you can fix a name, give a reason, or remove one.
//
//  Saves through SavedItemStore, same as the Share Extension.
//
//  App target only.
//

import SwiftUI
import SwiftData

struct AddItemView: View {

    @Environment(\.modelContext) private var context
    @State private var model = AddItemModel()
    @FocusState private var focus: Focus?

    private enum Focus: Hashable {
        case link
        case row(UUID)
    }

    // MARK: Readable slices of the model's state

    private var savedSummary: (title: String, coolingDays: Int)? {
        if case .saved(let title, let days) = model.phase { return (title, days) }
        return nil
    }
    private var saveError: String? {
        if case .failed(let message) = model.phase { return message }
        return nil
    }
    private var showingResults: Bool { model.phase == .batchResults }
    private var isSaving: Bool { model.phase == .saving || model.isScanning }

    /// Which screen is up — drives the crossfade.
    private var screen: Int {
        if savedSummary != nil { return 2 }
        if showingResults { return 3 }
        return model.mode == .one ? 0 : 1
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    switch screen {
                    case 2: successScreen
                    case 3: resultsScreen
                    case 1: multipleScreen
                    default: singleScreen
                    }
                }
                .transition(Self.crossfade)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.cream.ignoresSafeArea())
            .toolbarBackground(Theme.cream, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Theme.blue)
        // Don't let a swipe throw away saves that are halfway done.
        .interactiveDismissDisabled(isSaving)
        .sensoryFeedback(.success, trigger: savedSummary != nil) { _, saved in saved }
        .sensoryFeedback(.success, trigger: model.isScanning) { was, now in was && !now }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: screen)
        // The link reads itself shortly after you paste or stop typing.
        .task(id: model.single.parsedLink) {
            guard model.single.parsedLink != nil else { return }
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await model.single.lookUp()
        }
    }

    // MARK: Add one

    private var singleScreen: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("add something", subtitle: "paste a link, or just type a name") {
                modeButton("add multiple", systemImage: "list.bullet") {
                    focus = nil
                    model.switchTo(.multiple)
                }
            }

            linkField

            AddItemRow(draft: model.single)

            if let saveError { helper(saveError, tint: .red) }

            primaryButton(
                model.phase == .saving ? "saving…" : "save to wishlist",
                enabled: model.canSaveSingle,
                busy: model.phase == .saving
            ) {
                focus = nil
                model.saveSingle(in: context)
            }
        }
    }

    private var linkField: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.inkSoft.opacity(0.6))

            TextField("paste a link…", text: $model.single.linkText)
                .textFieldStyle(.plain)
                .font(Theme.body(15))
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($focus, equals: .link)
                .onSubmit { focus = nil; Task { await model.single.lookUp() } }

            if model.single.isLooking {
                ProgressView().controlSize(.small)
            } else if model.single.hasText {
                Button { model.single.clearLink() } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkSoft.opacity(0.45))
                .accessibilityLabel("Clear the link")
            } else {
                PasteButton(payloadType: String.self) { strings in
                    if let text = strings.first { model.single.linkText = text }
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(Theme.blue)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(model.single.isLinkValid ? Theme.ink.opacity(0.08) : .red.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: Add multiple — the list

    private var multipleScreen: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("add multiple", subtitle: "paste or type links — return for the next one") {
                modeButton("just one", systemImage: "square") {
                    focus = nil
                    model.switchTo(.one)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Divider().padding(.leading, 44)
                    }
                    linkRow(row)
                }
            }
            .padding(.vertical, 4)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
            )

            let count = model.linksToAdd.count
            primaryButton(
                count == 0 ? "add all to wishlist" : "add all \(count) to wishlist",
                enabled: count > 0,
                busy: false
            ) {
                focus = nil
                Task { await model.addAll(in: context) }
            }
        }
        .onAppear {
            // Straight into typing, like a new reminder.
            if let first = model.rows.first(where: { !$0.hasText }) ?? model.rows.first {
                focus = .row(first.id)
            }
        }
    }

    private func linkRow(_ row: AddDraft) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Circle()
                .strokeBorder(row.parsedLink != nil ? Theme.blue : Theme.inkSoft.opacity(0.35), lineWidth: 1.5)
                .background(Circle().fill(row.parsedLink != nil ? Theme.blue.opacity(0.15) : .clear))
                .frame(width: 20, height: 20)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }

            VStack(alignment: .leading, spacing: 2) {
                TextField("add a link…", text: Bindable(row).linkText)
                    .textFieldStyle(.plain)
                    .font(Theme.body(15))
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focus, equals: .row(row.id))
                    .onSubmit { nextRow(after: row) }
                    .onChange(of: row.linkText) {
                        if let moveTo = model.rowChanged(row) { focus = .row(moveTo.id) }
                    }

                if !row.isLinkValid {
                    Text("that doesn't look like a link")
                        .font(Theme.body(11))
                        .foregroundStyle(.red)
                }
            }

            if row.hasText {
                Button { model.removeRow(row) } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkSoft.opacity(0.4))
                .accessibilityLabel("Remove this link")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture { focus = .row(row.id) }
    }

    /// Return on a row: move to the empty row below, or make one.
    private func nextRow(after row: AddDraft) {
        guard row.hasText else { focus = nil; return }
        if let index = model.rows.firstIndex(where: { $0.id == row.id }),
           index + 1 < model.rows.count, !model.rows[index + 1].hasText {
            focus = .row(model.rows[index + 1].id)
        } else {
            focus = .row(model.insertRow(after: row).id)
        }
    }

    // MARK: Add multiple — the results

    private var resultsScreen: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(model.isScanning ? Theme.blue.opacity(0.12) : Theme.green)
                            .frame(width: 34, height: 34)
                        if model.isScanning {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    Text(resultsTitle)
                        .font(Theme.display(28))
                        .foregroundStyle(Theme.headlineGradient)
                        .contentTransition(.numericText())
                }
                Text("they'll rest on your shelf for \(ShelfSettings.coolingDays) days. add a reason while you're here — future you will thank you.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 20)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.isScanning)

            ForEach(model.results) { result in
                AddItemRow(draft: result) {
                    withAnimation { model.remove(result, in: context) }
                }
                .disabled(result.isLooking)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            if !model.isScanning {
                primaryButton("add more", systemImage: "plus", enabled: true, busy: false) {
                    model.reset()
                    model.switchTo(.multiple)
                }
                .padding(.top, 4)
                swipeDownHint
            }
        }
    }

    private var resultsTitle: String {
        if model.isScanning {
            let done = model.results.filter { !$0.isLooking }.count
            return "reading \(done) of \(model.results.count)…"
        }
        let count = model.savedCount
        return count == 1 ? "added 1 thing" : "added \(count) things"
    }

    // MARK: Add one — saved

    private var successScreen: some View {
        VStack(spacing: 18) {
            if let saved = savedSummary {
                // One way forward ("add another"); closing is a swipe down.
                SaveSuccessView(title: saved.title, coolingDays: saved.coolingDays) {
                    model.reset()
                }
            }
            swipeDownHint
        }
        .padding(.top, 24)
    }

    /// Each screen gets out of the way fast, then the next fades in,
    /// so two never sit on top of each other mid-crossfade.
    private static let crossfade = AnyTransition.asymmetric(
        insertion: .opacity.animation(.easeOut(duration: 0.25).delay(0.12)),
        removal: .opacity.animation(.easeIn(duration: 0.12))
    )

    /// After a save the sheet's job is done — point at the way out.
    private var swipeDownHint: some View {
        VStack(spacing: 4) {
            Image(systemName: "chevron.compact.down")
                .font(.system(size: 28, weight: .medium))
            Text("swipe down to close")
                .font(Theme.body(13))
        }
        .foregroundStyle(Theme.inkSoft.opacity(0.7))
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .accessibilityHidden(true)   // VoiceOver users get the sheet's own close gesture
    }

    // MARK: Small pieces

    private func header<Trailing: View>(
        _ title: String, subtitle: String, @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.display(32))
                    .foregroundStyle(Theme.headlineGradient)
                Text(subtitle)
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 8)
            trailing().padding(.top, 8)
        }
        .padding(.top, 20)   // clear of the sheet's drag handle
    }

    private func modeButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(Theme.body(12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.blue.opacity(0.1), in: Capsule())
                .foregroundStyle(Theme.blue)
        }
        .buttonStyle(.plain)
    }

    private func primaryButton(
        _ title: String, systemImage: String? = nil, enabled: Bool, busy: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if busy { ProgressView().controlSize(.small).tint(.white) }
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(Theme.body(16, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(enabled ? Theme.blue : Theme.inkSoft.opacity(0.25), in: Capsule())
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.top, 2)
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
