//
//  SaveSheetView.swift
//  Somewhere — the bottom sheet people see after Share → Somewhere.
//
//  Shows the screenshot as a polaroid, with the name and link pre-filled
//  (both editable), and a "save to wishlist" button. Styled from Theme.
//
//  Extension target only.
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
                    .tint(Theme.blue)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                failure(message)
            case .ready:
                content
            }
        }
        .background(Theme.cream.ignoresSafeArea())
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

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button("cancel", action: onCancel)
                .font(Theme.body(16, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    // MARK: Main content

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
                    .font(Theme.display(30))
                    .foregroundStyle(Theme.headlineGradient)
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
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .padding(6)
            .padding(.bottom, 14)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
            .rotationEffect(.degrees(-2))
            .frame(width: 112)
            .accessibilityHidden(true)
    }

    private var sourcePill: some View {
        let source = model.source
        return HStack(spacing: 4) {
            Image(systemName: source.symbol)
            Text(source.displayName)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(source.tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(source.tint.opacity(0.1), in: Capsule())
        .accessibilityLabel("Saved from \(source.displayName)")
    }

    @ViewBuilder
    private var helperText: some View {
        if model.isReading {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small).tint(Theme.blue)
                Text("reading your screenshot…")
            }
            .font(Theme.body(13))
            .foregroundStyle(Theme.inkSoft)
        } else {
            Text(model.foundSomething
                 ? "filled in what I could — fix anything that's off."
                 : "couldn't read much from this one — add a name below.")
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Name + link

    private var fieldsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NAME")
                .font(Theme.label)
                .foregroundStyle(Theme.blue)

            TextField("give it a name", text: $model.title, axis: .vertical)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1...3)
                .focused($focused)

            Divider().overlay(Theme.ink.opacity(0.05))

            Text("LINK")
                .font(Theme.label)
                .foregroundStyle(Theme.blue)

            HStack(spacing: 8) {
                Image(systemName: "link")
                    .foregroundStyle(Theme.inkSoft)
                TextField("paste the link (optional)", text: $model.linkText)
                    .font(Theme.body(16))
                    .foregroundStyle(Theme.ink)
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
                            .foregroundStyle(Theme.inkSoft.opacity(0.6))
                    }
                    .accessibilityLabel("Clear link")
                }
            }

            if !model.isLinkValid {
                Text("that doesn't look like a link yet")
                    .font(.caption)
                    .foregroundStyle(Theme.pink)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.ink.opacity(0.05)))
    }

    // MARK: Save button

    private var saveBar: some View {
        VStack(spacing: 8) {
            if case .failed(let message) = model.saveState {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Theme.pink)
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
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(model.saveState == .saved ? Theme.green : Theme.pink, in: Capsule())
            }
            .disabled(!model.canSave)
            .opacity(model.canSave || model.saveState == .saved || model.saveState == .saving ? 1 : 0.45)
            .animation(.snappy, value: model.saveState)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Theme.cream)
    }

    private var buttonTitle: String {
        switch model.saveState {
        case .saving: "saving…"
        case .saved:  "saved"
        default:      "save to shelf"
        }
    }

    // MARK: Can't save this

    private func failure(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.periwinkle)
            Text("can't save that one")
                .font(Theme.display(22))
                .foregroundStyle(Theme.headlineGradient)
            Text(message)
                .font(Theme.body(14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button("close", action: onCancel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.blue)
                .padding(.top, 6)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
