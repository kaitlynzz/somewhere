//
//  SaveSheetView.swift
//  Somewhere — the bottom sheet people see after Share → Somewhere.
//
//  Shows the screenshot as a polaroid, with the name and link pre-filled
//  (both editable), and a "save to wishlist" button. Styled from DesignSystem.
//
//  Karan: the sheet now also opens for a shared page, where there's no
//  picture until the page has been read (and sometimes none at all). Two
//  changes for that — placeholder artwork in the polaroid, and copy that
//  says "page" instead of "screenshot".
//
//  Extension target only.
//  Updated to use DesignSystem.swift (Muskaan).
//

import SwiftUI

struct SaveSheetView: View {
    @Bindable var model: ShareSaveModel
    var onDone: () -> Void
    var onCancel: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            topBar

            switch model.phase {
            case .loading:
                ProgressView()
                    .tint(Color.swBlue)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                failure(message)
            case .ready:
                content
            }
        }
        .background(Color.swPaper.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: model.saveState == .saved)
        .onChange(of: model.saveState) { _, state in
            guard state == .saved else { return }
            // Let the "saved" state register, then close the sheet.
            Task {
                try? await Task.sleep(for: .milliseconds(900))
                onDone()
            }
        }
    }

    // --- top bar

    private var topBar: some View {
        HStack {
            Button("cancel", action: onCancel)
                .swText(.body, color: .swMuted)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    // --- main content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                fieldsCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { saveBar }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            polaroid

            VStack(alignment: .leading, spacing: 10) {
                Text("save to\nsomewhere")
                    .swText(.display)
                    .fixedSize(horizontal: false, vertical: true)

                sourcePill

                helperText
            }
            Spacer(minLength: 0)
        }
    }

    private var polaroid: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image = model.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    // Karan: a shared page has no picture until it's been read,
                    // and some pages never give one. An empty frame reads as
                    // broken, so show something deliberate instead.
                    pagePlaceholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(6)
            .padding(.bottom, 14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.swLine, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            .rotationEffect(.degrees(-2))
            .frame(width: 112)
            .accessibilityHidden(true)
    }

    /// Karan: stand-in artwork for a shared page.
    private var pagePlaceholder: some View {
        ZStack {
            Color.swSky
            Image(systemName: model.isReading ? "ellipsis" : "link")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.swBlue)
        }
    }

    private var sourcePill: some View {
        let source = model.source
        return HStack(spacing: 4) {
            Image(systemName: source.symbol)
            Text(source.displayName)
        }
        .swText(.chip, color: source.labelTint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(source.tint.opacity(0.18), in: Capsule())
        .accessibilityLabel("Saved from \(source.displayName)")
    }

    @ViewBuilder
    private var helperText: some View {
        if model.isReading {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small).tint(Color.swBlue)
                // Karan: same spinner, right words for whichever we got.
                Text(model.origin == .link ? "reading the page…" : "reading your screenshot…")
            }
            .swText(.caption, color: .swMuted)
        } else {
            Text(model.foundSomething
                 ? "filled in what I could — fix anything that's off."
                 : (model.origin == .link
                    ? "that page didn't say much — add a name below."    // Karan
                    : "couldn't read much from this one — add a name below."))
                .swText(.caption, color: .swMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // --- name + link

    private var fieldsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NAME")
                .swText(.label, color: .swBlue)

            TextField("give it a name", text: $model.title, axis: .vertical)
                .swText(.headline)
                .lineLimit(1...3)
                .focused($focused)

            Divider().overlay(Color.swLine)

            Text("LINK")
                .swText(.label, color: .swBlue)

            HStack(spacing: 8) {
                Image(systemName: "link")
                    .foregroundStyle(Color.swMuted)
                TextField("paste the link (optional)", text: $model.linkText)
                    .swText(.body)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)

                if !model.linkText.isEmpty {
                    Button {
                        model.linkText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.swMuted.opacity(0.6))
                    }
                    .accessibilityLabel("Clear link")
                }
            }

            if !model.isLinkValid {
                Text("that doesn't look like a link yet")
                    .swText(.caption, color: .swError)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.swLine, lineWidth: 1))
    }

    // --- save button

    private var saveBar: some View {
        VStack(spacing: 8) {
            if case .failed(let message) = model.saveState {
                Text(message)
                    .swText(.caption, color: .swError)
                    .multilineTextAlignment(.center)
            }

            Button {
                focused = false
                model.save()
            } label: {
                HStack(spacing: 8) {
                    if model.saveState == .saved {
                        Image(systemName: "checkmark")
                    }
                    Text(buttonTitle)
                }
                .swText(.bodyStrong, color: .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(model.saveState == .saved ? Color.swStickerMint : Color.swStickerPink, in: Capsule())
            }
            .disabled(!model.canSave)
            .opacity(model.canSave || model.saveState == .saved || model.saveState == .saving ? 1 : 0.45)
            .animation(.snappy, value: model.saveState)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Color.swPaper)
    }

    private var buttonTitle: String {
        switch model.saveState {
        case .saving: "saving…"
        case .saved:  "saved"
        default:      "save to shelf"
        }
    }

    // --- can't save this

    private func failure(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color.swBlue)
            Text("can't save that one")
                .swText(.title)
            Text(message)
                .swText(.caption, color: .swMuted)
                .multilineTextAlignment(.center)
            Button("close", action: onCancel)
                .swText(.bodyStrong, color: .swBlue)
                .padding(.top, 6)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
