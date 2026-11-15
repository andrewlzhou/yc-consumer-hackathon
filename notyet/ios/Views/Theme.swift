// Target membership: app only. Colors, type and shared pieces for every screen.
// Look: black background, white text, dark Prussian blue as the brand color, square corners.
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

enum Config {
    // Paste your iCloud shortcut link and Whop checkout link here.
    static let shortcutURL = URL(string: "https://www.icloud.com/shortcuts/REPLACE_ME")!
    static let proCheckoutURL = URL(string: "https://whop.com/")!
}

enum Theme {
    // Core
    static let paper = Color.black                    // app background
    static let ink = Color.white                      // primary text
    static let slate = Color.white.opacity(0.6)       // secondary text
    static let hairline = Color.white.opacity(0.14)   // dividers and outlines
    static let prussian = Color(hex: 0x003153)        // brand: buttons, verdict panel, selected chips
    static let prussianLight = Color(hex: 0x4A86BD)   // brand tint that stays visible on black (icons, chart)

    // Verdicts, brightened for a dark background
    static let buy = Color(hex: 0x3DDC97)
    static let wait = Color(hex: 0xFFB547)
    static let fake = Color(hex: 0xFF5C5C)

    /// Big numbers and verdict words. Falls back to the system font if Bricolage isn't bundled.
    static func display(_ size: CGFloat) -> Font {
        .custom("BricolageGrotesque-Bold", size: size, relativeTo: .largeTitle)
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

    init(_ verdict: String?) {
        switch verdict {
        case "BUY_NOW": word = "Buy"; color = Theme.buy
        case "WAIT": word = "Wait"; color = Theme.wait
        case "FAKE_DEAL": word = "Fake deal"; color = Theme.fake
        default: word = "Checking"; color = Theme.slate
        }
    }
}

/// Square-cornered button. Filled Prussian blue, or outlined.
struct SharpButtonStyle: ButtonStyle {
    var filled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(filled ? Theme.prussian : Color.clear)
            .overlay(Rectangle().stroke(filled ? Color.clear : Theme.hairline, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Square chip for filters and choices.
struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Theme.prussian : Color.clear)
                .overlay(Rectangle().stroke(selected ? Color.clear : Theme.hairline, lineWidth: 1))
                .foregroundStyle(Theme.ink)
        }
        .buttonStyle(.plain)
    }
}

struct RetailerBadge: View {
    let name: String
    var body: some View {
        Text(name.lowercased())
            .font(.caption.bold())
            .foregroundStyle(Theme.ink.opacity(0.85))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))
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
    var body: some View { Rectangle().fill(Theme.hairline).frame(height: 1) }
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
