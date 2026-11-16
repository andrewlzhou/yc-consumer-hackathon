// Copied from notyet/ios/Views/DesignSystem/Palette.swift (Not Yet).
// Warm neutrals in the Anthropic style (owner, 2026-11-15): a warm near-black canvas, warm off-white
// text at fixed opacities, white at fixed opacities for fills and strokes, and one orange accent used
// sparingly. Dark only. The structure follows Worldscape's palette (worldscape DS/Palette.swift).
import SwiftUI

extension Color {
    // `Color(hex: 0xD97757)` or `Color(hex: 0xD97757, opacity: 0.5)`, in sRGB.
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
    static let canvas = Color(hex: 0x141413)
    // The one accent: the primary action, focus (carets) and selected states only.
    static let accent = Color(hex: 0xD97757)
    // Neutral grey for quiet marks that must show on the canvas (the chart's 12-month low).
    static let muted = Color(hex: 0xB0AEA5)
    // A solid mid grey for fills that carry white text (avatar, swipe action).
    static let stone = Color(hex: 0x5E5D58)

    // Text: warm off-white.
    private static let ivory = Color(hex: 0xFAF9F5)
    static let textPrimary = ivory.opacity(0.94)
    static let textSecondary = ivory.opacity(0.62)
    static let textTertiary = ivory.opacity(0.36)

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

    // Errors only.
    static let danger = Color(hex: 0xFF5C7A)
}
