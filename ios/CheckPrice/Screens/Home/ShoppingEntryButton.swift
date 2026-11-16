// Home's "Back to Shopping" entry (owner, 2026-11-15: "make it a unique new button instead of using
// old design elements"). A one-off tile, not built from KeyButtonStyle, FlatCard, HomeCard or Chip:
// a 96pt-tall dark glass tile with a cream-to-orange 1pt border; on the left a facepile of the top
// four stores as monograms, in the middle the label and a line about the top store, on the right a
// bar per store with the tallest in the accent. Every number comes from `ShoppingStatsSample`.
// Pressing shrinks it to 0.97 and brightens the border; no idle animation.
import SwiftUI

private typealias Stats = ShoppingStatsSample

struct ShoppingEntryButton: View {
    let action: () -> Void
    @State private var taps = 0

    private let stores = Array(Stats.storesByChecks.prefix(4))

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            HStack(spacing: 14) {
                StoreFacepile(stores: stores)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Back to Shopping")
                        .font(.hiragino(.w6, size: 19, relativeTo: .headline))
                        .foregroundStyle(Palette.textPrimary)
                    if let top = stores.first {
                        Text("Most checks at \(top.name) · \(top.checks) this year")
                            .textStyle(.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                StoreBars(stores: stores)
            }
            .padding(.horizontal, 18)
        }
        .buttonStyle(ShoppingEntryPressStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .accessibilityLabel("Back to Shopping")
        .accessibilityHint("Shows which stores you shop at most")
    }
}

// The tile itself: glass, the gradient border, and the press (scale 0.97, brighter border).
private struct ShoppingEntryPressStyle: ButtonStyle {
    private static let cream = Color(hex: 0xFAF9F5)
    private let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .background(.ultraThinMaterial, in: shape)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Self.cream.opacity(pressed ? 0.6 : 0.35), Palette.accent.opacity(pressed ? 1 : 0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .environment(\.colorScheme, .dark)
            .contentShape(shape)
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(pressed ? Motion.pressDown : Motion.pressRelease, value: pressed)
    }
}

// The top stores as overlapping 34pt monogram circles (10pt overlap), the top store in front. Each
// has its own warm muted fill and a 2pt canvas ring that separates it from the one behind.
private struct StoreFacepile: View {
    let stores: [ShoppingStatsSample.Store]

    // Stone, sand, clay, dark cream: warm neutrals beside the palette's stone. Text on each.
    private static let fills: [(fill: Color, text: Color)] = [
        (Palette.stone, Palette.textPrimary),
        (Color(hex: 0x857B6C), Palette.textPrimary),
        (Color(hex: 0x8E6A5A), Palette.textPrimary),
        (Color(hex: 0xC9C1B1), Palette.canvas),
    ]

    var body: some View {
        HStack(spacing: -10) {
            ForEach(Array(stores.enumerated()), id: \.element.id) { index, store in
                let style = Self.fills[index % Self.fills.count]
                Text(monogram(store.name))
                    .font(.hiragino(.w6, size: 13, relativeTo: .caption))
                    .foregroundStyle(style.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 34, height: 34)
                    .background(style.fill, in: Circle())
                    .overlay { Circle().strokeBorder(Palette.canvas, lineWidth: 2) }
                    .zIndex(Double(stores.count - index))
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .accessibilityHidden(true)
    }

    // First letter of each word: "Best Buy" → "BB".
    private func monogram(_ name: String) -> String {
        String(name.split(separator: " ").compactMap(\.first)).uppercased()
    }
}

// One thin capsule per store, 5pt wide with 3pt gaps, scaled so the tallest is 36pt. The tallest is
// the accent; the rest are warm off-white at 30%.
private struct StoreBars: View {
    let stores: [ShoppingStatsSample.Store]

    var body: some View {
        let top = max(stores.map(\.checks).max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(stores) { store in
                Capsule()
                    .fill(store.checks == top ? Palette.accent : Color(hex: 0xFAF9F5, opacity: 0.3))
                    .frame(width: 5, height: max(5, 36 * CGFloat(store.checks) / CGFloat(top)))
            }
        }
        .frame(height: 36, alignment: .bottom)
        .accessibilityHidden(true)
    }
}
