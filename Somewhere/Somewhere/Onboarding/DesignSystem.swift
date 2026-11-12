//
//  DesignSystem.swift
//  somewhereapp
//
//  Created by Muskaan Bajaj on 11/10/26.
//

import SwiftUI

// --- color palette
// central spot for all the somewhere* colors from the design guide
extension Color {
    // base backgrounds & text
    static let swPaper = Color(hex: "FAFAF7")
    static let swInk = Color(hex: "111111")
    static let swMuted = Color(hex: "5F5E5A")
    static let swLine = Color(hex: "E6E3DC")
    static let swSurfaceSunk = Color(hex: "F1F3EC")
    
    // primary brand pop (only use one per screen area!)
    static let swBlue = Color(hex: "2F5BEA")
    static let swSky = Color(hex: "DCE5FD")
    static let swBlue50 = Color(hex: "E8EEFD")
    
    // sticker accents only
    static let swStickerPink = Color(hex: "F7A8CB")
    static let swStickerButter = Color(hex: "F7D040")
    static let swStickerMint = Color(hex: "A6E2BE")
}

// --- hex helper
// Color(hex:) now lives in UI/Theme.swift (Nicole's), shared by the whole app.

// --- typography system
// inter font styles matching the design scale (always lowercase headlines!)
enum SWTextStyle {
    case display
    case title
    case headline
    case body
    case bodyStrong
    case voice
    case label
    case caption

    var font: Font {
        switch self {
        case .display: return .custom("Inter-ExtraBold", size: 48)
        case .title: return .custom("Inter-ExtraBold", size: 30)
        case .headline: return .custom("Inter-Bold", size: 20)
        case .body: return .custom("Inter-Regular", size: 16)
        case .bodyStrong: return .custom("Inter-Medium", size: 15)
        case .voice: return .custom("Inter-SemiBoldItalic", size: 15)
        case .label: return .custom("Inter-SemiBold", size: 11)
        case .caption: return .custom("Inter-Regular", size: 12)
        }
    }

    var tracking: CGFloat {
        switch self {
        case .display: return -0.06 * 48
        case .title: return -0.045 * 30
        case .headline: return -0.03 * 20
        case .label: return 0.12 * 11
        case .voice: return 0
        default: return -0.15
        }
    }
}

extension View {
    // quick wrapper for apply text style + color together
    func swText(_ style: SWTextStyle, color: Color = .swInk) -> some View {
        self
            .font(style.font)
            .tracking(style.tracking)
            .foregroundStyle(color)
    }
}

// --- reusable button styles

/// main action button (48pt height, 12pt radius per spec)
struct SWPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Inter-Bold", size: 16))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.swBlue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// side-by-side choice buttons (used on cooling shelf & notification cards)
struct SWChoiceButtonStyle: ButtonStyle {
    enum Kind { case light, dark }
    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Inter-SemiBold", size: 14))
            .foregroundStyle(kind == .dark ? Color.swPaper : Color.swInk)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                kind == .dark ? Color.swInk : Color.white,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(kind == .dark ? Color.clear : Color.swLine, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// --- brand elements

/// blue asterisk icon component
struct AsteriskMark: View {
    var size: CGFloat = 24
    var color: Color = .swBlue

    var body: some View {
        Image(systemName: "asterisk")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(color)
    }
}

/// small pill sticker badge
struct SWSticker: View {
    let text: String
    var color: Color = .swStickerButter
    var tilt: Double = 0.0

    var body: some View {
        Text(text)
            .font(.custom("Inter-SemiBold", size: 12))
            .foregroundStyle(Color.swInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color, in: Capsule())
            .rotationEffect(.degrees(tilt))
    }
}

/// polaroid card frame for previewing saved items
struct SWSaveCard<Content: View>: View {
    let title: String
    var tilt: Double = 0.0
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(title)
                .swText(.bodyStrong)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }
        .padding(10)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        .rotationEffect(.degrees(tilt))
    }
}
