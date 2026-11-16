// Target membership: app only.
// Flat surfaces: everything that is not a key or glass has no depth (worldscape
// F/Chat/MessageColumn.swift `Bubble`, F/Settings/RowCard.swift).
import SwiftUI

// A flat rounded fill with a 0.5pt edge. The corner radius is half a one-line bubble's height,
// so one line reads as a pill. Own messages are a little lighter; replies a shade deeper.
struct Bubble<Content: View>: View {
    var isPerson: Bool
    var fontSize: CGFloat
    let content: Content

    init(isPerson: Bool = false, fontSize: CGFloat = TextStyle.body.size, @ViewBuilder content: () -> Content) {
        self.isPerson = isPerson
        self.fontSize = fontSize
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: fontSize / 2 + Spacing.bubbleVertical, style: .continuous)
        content
            .padding(.horizontal, Spacing.bubbleHorizontal)
            .padding(.vertical, Spacing.bubbleVertical)
            .background { isPerson ? Palette.fillBubbleOwn : Palette.fillBubbleReply }
            .clipShape(shape)
            .overlay { shape.strokeBorder(.white.opacity(isPerson ? 0.1 : 0.06), lineWidth: 0.5) }
    }
}

// A quiet card for lists and settings: white 3% fill, a 1pt border fading downward, and a deep
// shadow. Put rows inside with their own padding; separate them with `Hairline()`.
struct FlatCard<Content: View>: View {
    var cornerRadius: CGFloat
    let content: Content

    init(cornerRadius: CGFloat = Radius.listCard, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape
                    .fill(Palette.fillCard)
                    .overlay {
                        shape.strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1
                        )
                    }
                    .dropShadow(Shadows.listCard)
            }
    }
}

// A capsule chip for filters and choices: white 10% fill, brighter while pressed. Selected chips
// fill white 22% with primary text and a brighter outline (an iOS addition: Worldscape has no
// selected chip). The capsule is 32pt; the hit area is 44pt.
struct Chip: View {
    let title: String
    var symbol: String?
    let selected: Bool
    let action: () -> Void

    init(title: String, symbol: String? = nil, selected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.selected = selected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .textStyle(.caption)
                    .lineLimit(1)
            }
        }
        .buttonStyle(ChipStyle(selected: selected))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ChipStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .foregroundStyle(selected || pressed ? Palette.textPrimary : Palette.textSecondary)
            .padding(.horizontal, 14)
            .frame(height: ControlHeight.chip)
            .background {
                Capsule().fill(.white.opacity(selected ? 0.22 : (pressed ? 0.16 : 0.10)))
            }
            .overlay {
                Capsule().strokeBorder(selected ? Palette.strokeHover : Color.clear, lineWidth: 1)
            }
            .frame(height: ControlHeight.minTouch)
            .contentShape(Rectangle())
            .animation(Motion.hover, value: pressed)
            .animation(Motion.hover, value: selected)
    }
}
