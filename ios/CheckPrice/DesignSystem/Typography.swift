// Copied from notyet/ios/Views/DesignSystem/Typography.swift (Not Yet).
// Hiragino Sans in named roles (worldscape DS/Typography.swift). Weight follows importance.
//
// iOS differences from the Mac source:
// - Sizes are larger by 1-2pt (the Mac sizes were chosen for a screen at arm's length).
// - Text scales with Dynamic Type through `relativeTo`.
// - iOS ships Hiragino Sans only as W3, W6 and W7 (W4 and W5 are macOS only). Each weight
//   names one of those three PostScript names directly: regular and medium → W3,
//   semibold → W6, bold and heavy → W7. (A runtime lookup by family name used to fall back to
//   the system font on device.)
// - Hiragino sets at 1.0 line height. Give multi-line text an explicit `.lineSpacing` (2-8pt).
import SwiftUI

enum HiraginoWeight: Int, CaseIterable {
    // w3/w4 regular, w5 medium, w6 semibold, w7 bold. Kept as the Mac weight names so roles
    // read the same as the source; `fontName` is what iOS actually has.
    case w3 = 3, w4, w5, w6, w7

    var fontName: String {
        switch self {
        case .w3, .w4, .w5: "HiraginoSans-W3"
        case .w6: "HiraginoSans-W6"
        case .w7: "HiraginoSans-W7"
        }
    }
}

extension Font {
    // Hiragino Sans at a weight, scaled with Dynamic Type.
    static func hiragino(
        _ weight: HiraginoWeight,
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        .custom(weight.fontName, size: size, relativeTo: textStyle)
    }
}

enum TextStyle {
    // The brand word, very large. Tracking −0.03 × size.
    case wordmark(size: CGFloat)
    // A large regular-weight sentence. Tracking −0.012 × size; use line spacing 0.3 × size.
    case statement(size: CGFloat)
    case title
    // Title on a glass card.
    case cardTitle
    // Reading text, chat bubbles, field text.
    case body
    // Key labels.
    case button
    // List rows and names.
    case item
    // Field labels.
    case label
    case link
    case caption
    // Labels on small keys.
    case smallButton
    // Small headings over a list.
    case section
    // Small print: times, sources, hints.
    case footnote

    var weight: HiraginoWeight {
        switch self {
        case .wordmark, .title, .cardTitle: .w6
        case .button, .smallButton: .w5
        case .statement, .body, .item, .label, .link, .caption, .section, .footnote: .w4
        }
    }

    // Point size on iOS (Mac size in brackets).
    var size: CGFloat {
        switch self {
        case .wordmark(let size), .statement(let size): size
        case .title: 28         // [28]
        case .cardTitle: 16     // [14]
        case .body: 16          // [14]
        case .button: 16        // [14]
        case .item: 15          // [13]
        case .label, .link: 14  // [12.5]
        case .caption: 13       // [12]
        case .smallButton: 13   // [12]
        case .section, .footnote: 12 // [11]
        }
    }

    var tracking: CGFloat {
        switch self {
        case .wordmark(let size): -0.03 * size
        case .statement(let size): -0.012 * size
        case .title: -0.4
        case .cardTitle: -0.1
        case .label, .link, .caption, .footnote: 0.1
        case .section: 0.3
        case .item, .body: 0
        case .button, .smallButton: 0.2
        }
    }

    // The Dynamic Type style this role scales with.
    var dynamicTypeStyle: Font.TextStyle {
        switch self {
        case .wordmark, .title: .largeTitle
        case .statement: .title
        case .cardTitle: .headline
        case .body, .button, .item: .body
        case .label, .link, .smallButton: .subheadline
        case .caption: .caption
        case .section, .footnote: .footnote
        }
    }

    var font: Font {
        .hiragino(weight, size: size, relativeTo: dynamicTypeStyle)
    }
}

extension View {
    // Font and tracking for a role: `Text("Buy").textStyle(.title)`.
    func textStyle(_ style: TextStyle) -> some View {
        font(style.font).tracking(style.tracking)
    }
}
