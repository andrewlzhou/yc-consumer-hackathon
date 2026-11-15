// Target membership: app only.
// Hiragino Sans in named roles (worldscape DS/Typography.swift). Weight follows importance:
// W6 titles, W5 button labels, W4 everything else. Large type tightens, small type opens.
//
// iOS differences from the Mac source:
// - Sizes are larger by 1-2pt (the Mac sizes were chosen for a screen at arm's length).
// - Text scales with Dynamic Type through `relativeTo`.
// - iOS has historically shipped only some Hiragino Sans weights (W3, W6, W7). Each weight is
//   checked on the device: W4 falls back to W3, W5 to W6, and if neither exists, the system font
//   at a matching weight.
// - Hiragino sets at 1.0 line height. Give multi-line text an explicit `.lineSpacing` (2-8pt).
import SwiftUI
import UIKit

enum HiraginoWeight: Int, CaseIterable {
    case w3 = 3, w4, w5, w6, w7

    var fontName: String { "HiraginoSans-W\(rawValue)" }

    // Names to try, in order, before falling back to the system font.
    fileprivate var candidates: [HiraginoWeight] {
        switch self {
        case .w3: [.w3, .w4]
        case .w4: [.w4, .w3]
        case .w5: [.w5, .w6]
        case .w6: [.w6, .w7]
        case .w7: [.w7, .w6]
        }
    }

    fileprivate var systemWeight: Font.Weight {
        switch self {
        case .w3: .regular
        case .w4: .regular
        case .w5: .medium
        case .w6: .semibold
        case .w7: .bold
        }
    }
}

private enum HiraginoInstalled {
    // Font names the device has, read once.
    static let names: Set<String> = Set(UIFont.fontNames(forFamilyName: "Hiragino Sans"))

    static func name(for weight: HiraginoWeight) -> String? {
        weight.candidates.first { names.contains($0.fontName) }?.fontName
    }
}

extension Font {
    // Hiragino Sans at a weight, scaled with Dynamic Type. Falls back as described above.
    static func hiragino(
        _ weight: HiraginoWeight,
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        if let name = HiraginoInstalled.name(for: weight) {
            return .custom(name, size: size, relativeTo: textStyle)
        }
        return .system(size: size, weight: weight.systemWeight)
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
