//
//  DominantColor.swift
//  Somewhere — finds a screenshot's main colour so "blue bag" searches work.
//
//  Fills SavedItem.colorName / colorHex. Names match the families
//  WishlistSearch.colorSynonyms maps to: red, orange, yellow, green, blue,
//  purple, pink, brown, black, white, gray.
//
//  Looks at the centre of the picture (screenshots have app chrome around
//  the edges) and picks the most common *colourful* hue. If the picture is
//  basically neutral, it reports black / white / gray instead.
//
//  Extension target only.
//

import CoreGraphics
import Foundation

enum DominantColor {

    struct Result: Sendable {
        let name: String
        let hex: String
    }

    private struct Bucket {
        var count = 0
        var r = 0.0, g = 0.0, b = 0.0

        mutating func add(_ red: Double, _ green: Double, _ blue: Double) {
            count += 1; r += red; g += green; b += blue
        }

        var average: (Double, Double, Double) {
            count == 0 ? (0, 0, 0) : (r / Double(count), g / Double(count), b / Double(count))
        }
    }

    nonisolated static func find(in image: CGImage) -> Result? {
        // Shrink to 48×48 — plenty to judge colour, and cheap.
        let side = 48
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drew = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side,
                bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drew else { return nil }

        let margin = Int(Double(side) * 0.15)
        var hueBuckets = [Bucket](repeating: Bucket(), count: 12)   // 30° each
        var everything = Bucket()

        for y in margin..<(side - margin) {
            for x in margin..<(side - margin) {
                let i = (y * side + x) * 4
                let r = Double(pixels[i]) / 255
                let g = Double(pixels[i + 1]) / 255
                let b = Double(pixels[i + 2]) / 255
                let (hue, saturation, value) = hsv(r, g, b)

                everything.add(r, g, b)
                if saturation > 0.25, value > 0.2 {
                    hueBuckets[min(Int(hue / 30), 11)].add(r, g, b)
                }
            }
        }
        guard everything.count > 0, let best = hueBuckets.max(by: { $0.count < $1.count }) else { return nil }

        // A colour needs ~10% of the middle of the picture to count; otherwise call it neutral.
        let isColourful = Double(best.count) / Double(everything.count) >= 0.10
        let (r, g, b) = (isColourful ? best : everything).average
        return Result(name: name(r, g, b), hex: hex(r, g, b))
    }

    // MARK: Colour maths

    private nonisolated static func hsv(_ r: Double, _ g: Double, _ b: Double) -> (h: Double, s: Double, v: Double) {
        let maxC = max(r, g, b), minC = min(r, g, b)
        let delta = maxC - minC
        var hue = 0.0
        if delta > 0 {
            if maxC == r {
                hue = 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxC == g {
                hue = 60 * ((b - r) / delta + 2)
            } else {
                hue = 60 * ((r - g) / delta + 4)
            }
        }
        if hue < 0 { hue += 360 }
        return (hue, maxC == 0 ? 0 : delta / maxC, maxC)
    }

    private nonisolated static func name(_ r: Double, _ g: Double, _ b: Double) -> String {
        let (h, s, v) = hsv(r, g, b)
        if v < 0.2 { return "black" }
        if s < 0.18 { return v > 0.8 ? "white" : "gray" }

        switch h {
        case 345..<360, 0..<15:  return (s < 0.5 && v > 0.75) ? "pink" : "red"
        case 15..<45:            return (v < 0.65 || s < 0.4) ? "brown" : "orange"
        case 45..<70:            return "yellow"
        case 70..<165:           return "green"
        case 165..<255:          return "blue"
        case 255..<290:          return "purple"
        default:                 return "pink"
        }
    }

    private nonisolated static func hex(_ r: Double, _ g: Double, _ b: Double) -> String {
        String(format: "#%02X%02X%02X",
               Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
}
