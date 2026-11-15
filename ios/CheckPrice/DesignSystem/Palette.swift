// Copied from notyet/ios/Views/DesignSystem/Palette.swift (Not Yet).
// Worldscape palette (worldscape DS/Palette.swift): one near-black canvas, a family of blues, and
// white at fixed opacities for text, fills and strokes. Dark only.
import SwiftUI

extension Color {
    // `Color(hex: 0x005EFF)` or `Color(hex: 0x005EFF, opacity: 0.5)`, in sRGB.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Palette {
    // Canvas and the blue family.
    static let canvas = Color(hex: 0x010101)
    // Primary: actions and focus.
    static let electric = Color(hex: 0x005EFF)
    // Secondary blue.
    static let iris = Color(hex: 0x4A56FF)
    // Tertiary blue, the gradient's depth.
    static let ultramarine = Color(hex: 0x1500FF)
    // Lightest blue: highlights, search match, streaming caret, tints that must show on black.
    static let glow = Color(hex: 0x436FFF)

    // Text.
    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.36)

    // Strokes. On iOS `strokeHover` is the pressed outline.
    static let stroke = Color.white.opacity(0.16)
    static let strokeHover = Color.white.opacity(0.24)
    static let divider = Color.white.opacity(0.06)

    // Flat fills.
    static let fillBar = Color.white.opacity(0.06)
    static let fillCard = Color.white.opacity(0.03)
    static let fillRowPressed = Color.white.opacity(0.05)
    static let fillChip = Color.white.opacity(0.10)
    static let fillChipPressed = Color.white.opacity(0.16)
    static let fillBubbleOwn = Color.white.opacity(0.10)
    static let fillBubbleReply = Color.black.opacity(0.16)

    // Links on dark glass, and the quiet blue label ("2 replies").
    static let link = Color(hex: 0x8CA8FF)
    static let linkPressed = Color(hex: 0xADC1FF)
    static let quietBlue = Color(hex: 0x6C8CFF).opacity(0.78)

    // Errors only.
    static let danger = Color(hex: 0xFF5C7A)
}
