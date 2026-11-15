// Target membership: app only. Old token names and shared pieces, now drawn in the Worldscape
// design language (tokens and components live in Views/DesignSystem/). The names below are kept
// so existing screens keep compiling; new code should use `Palette`, `TextStyle` and the
// DesignSystem components directly.
import SwiftUI

enum Config {
    // Paste your iCloud shortcut link and Whop checkout link here.
    static let shortcutURL = URL(string: "https://www.icloud.com/shortcuts/REPLACE_ME")!
    static let proCheckoutURL = URL(string: "https://whop.com/")!
}

enum Theme {
    // Old names mapped onto the Worldscape palette.
    static let paper = Palette.canvas               // app background
    static let ink = Palette.textPrimary            // primary text
    static let slate = Palette.textSecondary        // secondary text
    static let hairline = Palette.stroke            // outlines (dividers: `Hairline()`)
    static let prussian = Palette.electric          // brand fill: the one blue action or panel
    static let prussianLight = Palette.glow         // blue that stays visible on black (icons, chart, tint)

    // Verdicts. Worldscape has no verdict colours; green and amber are kept from the original
    // design, and the red is Worldscape's danger red.
    static let buy = Color(hex: 0x3DDC97)
    static let wait = Color(hex: 0xFFB547)
    static let fake = Palette.danger

    // Big numbers and verdict words, in Hiragino Sans W6.
    static func display(_ size: CGFloat) -> Font {
        .hiragino(.w6, size: size, relativeTo: .largeTitle)
    }

    static func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    /// "2026-11-30" -> Date
    static func day(_ s: String?) -> Date? {
        guard let s else { return nil }
        return ISO8601DateFormatter().date(from: s + "T12:00:00Z")
    }

    /// Date -> "2026-11-30"
    static func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// A rough product icon from its name, for list rows.
    static func productSymbol(_ name: String?) -> String {
        let n = (name ?? "").lowercased()
        let map: [(String, String)] = [
            ("airpod", "airpodspro"), ("headphone", "headphones"), ("earbud", "earbuds"),
            ("watch", "applewatch"), ("iphone", "iphone"), ("ipad", "ipad"), ("tablet", "ipad"),
            ("macbook", "laptopcomputer"), ("laptop", "laptopcomputer"), ("monitor", "display"),
            ("switch", "gamecontroller"), ("playstation", "gamecontroller"), ("ps5", "gamecontroller"),
            ("xbox", "gamecontroller"), ("camera", "camera"), ("speaker", "hifispeaker"),
            ("kindle", "book"), ("vacuum", "fan"), ("dyson", "fan"), ("fridge", "refrigerator"),
            ("refrigerator", "refrigerator"), ("sneaker", "shoe"), ("shoe", "shoe"),
            ("jacket", "tshirt"), ("shirt", "tshirt"), ("tv", "tv"), ("phone", "iphone"),
        ]
        return map.first { n.contains($0.0) }?.1 ?? "bag"
    }
}

struct VerdictStyle {
    let word: String
    let color: Color

    // Old entry point, kept for callers; the words and colors come from the shared Verdict table.
    init(_ verdict: String?) {
        let v = Verdict(verdict)
        word = v.word
        color = v == .unknown ? Theme.slate : v.color
    }
}

// Old button name. Filled is the primary key; outlined is the quiet key. Both 50pt tall.
struct SharpButtonStyle: ButtonStyle {
    var filled = true

    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if filled {
            KeyButtonStyle(tone: .primary, height: ControlHeight.mainKey).makeBody(configuration: configuration)
        } else {
            QuietButtonStyle(height: ControlHeight.mainKey).makeBody(configuration: configuration)
        }
    }
}

struct RetailerBadge: View {
    let name: String
    var body: some View {
        Text(name.lowercased())
            .textStyle(.footnote)
            .foregroundStyle(Palette.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Palette.fillChip))
    }
}

struct StarsView: View {
    let rating: Double
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: Self.symbol(rating - Double(i)))
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.wait)
        .accessibilityLabel(String(format: "%.1f out of 5 stars", rating))
    }

    private static func symbol(_ fill: Double) -> String {
        if fill >= 0.75 { return "star.fill" }
        if fill >= 0.25 { return "star.leadinghalf.filled" }
        return "star"
    }
}

struct Hairline: View {
    var body: some View { Rectangle().fill(Palette.divider).frame(height: 1) }
}

// The gear in the top-right corner of every tab.
private struct SettingsToolbar: ViewModifier {
    @State private var showSettings = false
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsSheet().preferredColorScheme(.dark) }
    }
}

extension View {
    func settingsButton() -> some View { modifier(SettingsToolbar()) }
}
