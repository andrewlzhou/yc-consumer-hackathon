// Adapted from notyet/ios/Views/DesignSystem/VerdictColors.swift and the word/symbol table on
// Not Yet's `Verdict` (notyet/ios/App/Models.swift), mapped onto Check Price's four verdicts.
// Worldscape has no verdict colours: green and amber come from Not Yet's original design, and the
// two newer verdicts use lavender and sand so neither is mistaken for the other two. Check first
// was coral (#FF9466) until it sat beside the orange accent on Library rows; sand keeps it apart.
import SwiftUI

extension Verdict {
    // The big word on the reveal and the report.
    var word: String {
        switch self {
        case .buyNow: "Buy"
        case .wait: "Wait"
        case .alternative: "Look around"
        case .investigate: "Check first"
        }
    }

    // SF Symbol beside the word.
    var symbol: String {
        switch self {
        case .buyNow: "checkmark.circle.fill"
        case .wait: "clock.fill"
        case .alternative: "arrow.left.arrow.right.circle.fill"
        case .investigate: "magnifyingglass.circle.fill"
        }
    }

    // sRGB hex of the verdict colour.
    var rgb: UInt32 {
        switch self {
        case .buyNow: 0x3DDC97      // green
        case .wait: 0xFFB547        // amber
        case .alternative: 0xC4A7FF // lavender
        case .investigate: 0xCFC0A3 // sand
        }
    }

    var color: Color { Color(hex: rgb) }
}
