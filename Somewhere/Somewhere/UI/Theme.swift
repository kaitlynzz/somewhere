//
//  Theme.swift
//  Somewhere — colours + type pulled from the pitch deck.
//

import SwiftUI

enum Theme {
    // Backgrounds
    static let cream      = Color(hex: "#F6F3EC")   // deck slide background
    static let paper      = Color(hex: "#FDFCF8")   // cards
    static let lavender   = Color(hex: "#E9EDFB")   // "cooling shelf" slide

    // Ink
    static let ink        = Color(hex: "#1F1F24")
    static let inkSoft    = Color(hex: "#5B5B66")

    // Accents
    static let periwinkle = Color(hex: "#7F93EA")   // "somewhere" / headline italic
    static let blue       = Color(hex: "#3B63D9")   // "faster"
    static let pink       = Color(hex: "#D4559A")   // "find them"
    static let pinkSoft   = Color(hex: "#F8D9E8")
    static let green      = Color(hex: "#4DAE68")   // "fun fact" tag
    static let greenSoft  = Color(hex: "#D9F0DE")
    static let yellow     = Color(hex: "#F7E27C")   // sticky notes
    static let sun        = Color(hex: "#E9B949")   // ":)"

    static let headlineGradient = LinearGradient(
        colors: [Color(hex: "#6E86E6"), Color(hex: "#A7B5F3")],
        startPoint: .leading, endPoint: .trailing
    )

    // MARK: Type
    // Optional: add "Gochi Hand" (Google Fonts, OFL) to the bundle + Info.plist (UIAppFonts)
    // for the handwritten captions. Without it SwiftUI quietly falls back to the system font.

    /// Big italic heavy headline: "my wishlist", "the cooling shelf".
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).italic()
    }

    /// Handwritten polaroid caption: "the perfect shoes".
    static func hand(_ size: CGFloat) -> Font {
        .custom("GochiHand-Regular", size: size, relativeTo: .body)
    }

    static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Small caps label: "THE PROBLEM", "SAVED FROM".
    static let label = Font.system(size: 11, weight: .bold).width(.expanded)
}

extension SourceApp {
    var tint: Color {
        switch self {
        case .tiktok:     Theme.ink
        case .instagram:  Theme.pink
        case .pinterest:  Color(hex: "#C8323A")
        case .safari:     Theme.blue
        case .screenshot: Theme.green
        case .other:      Theme.inkSoft
        }
    }
}

extension Color {
    /// "#RRGGBB" or "RRGGBB". Bad input → gray.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        var value: UInt64 = 0
        guard cleaned.count == 6, Scanner(string: cleaned).scanHexInt64(&value) else {
            self = .gray
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
