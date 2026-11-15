// Target membership: app only.
// The pieces the ways into a check share (worldscape F/CommandBar/BarSurface.swift,
// CommandBarParts.swift, F/Chat/MessageColumn.swift): the blue input bar's surface, the
// "dots + current step" line while an answer is on its way, the failure line with the one thing
// that fixes it, and round icon presses. List rows use `ListRowButtonStyle` and `RoundIcon`
// (ListScreens.swift).
import SwiftUI

// The blue input bar's surface: deep brand blue over frosted glass, darkest at the top, easing into
// a faint fog along the bottom, under a hairline rim (accent blue on top, steel along the bottom),
// over a blurred shadow. The fog keeps a fixed height as the bar grows. iOS: the Mac's behind-window
// blur is `.ultraThinMaterial`, which only blurs the app's own content; the colours carry the look.
struct InputBarSurface: View {
    var cornerRadius: CGFloat = ControlHeight.inputBar / 2
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private static let fog = Color(hex: 0xDDE6FF)
    private static let fogHeight: CGFloat = 30
    // Banks of fog along the bottom edge, a little thicker toward the right: x, width (fractions
    // of the bar), height, opacity.
    private static let banks: [(x: CGFloat, width: CGFloat, height: CGFloat, opacity: Double)] = [
        (0.14, 0.55, 34, 0.08),
        (0.48, 0.6, 32, 0.1),
        (0.8, 0.6, 38, 0.16),
    ]
    private static let rim = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x6B88FF).opacity(0.9), location: 0),
            .init(color: Color(hex: 0x93A5E8).opacity(0.55), location: 0.5),
            .init(color: Color(hex: 0x5F6C90).opacity(0.8), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape
                .fill(Color(hex: 0x01061F).opacity(0.4))
                .blur(radius: 14)
                .offset(y: 8)
            fill.clipShape(shape)
            shape.strokeBorder(Self.rim, lineWidth: 0.5)
        }
    }

    private var fill: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                if reduceTransparency {
                    Color(hex: 0x0B0C12)
                } else {
                    Rectangle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
                }
                LinearGradient(
                    colors: [Color(hex: 0x0E0FA2), Color(hex: 0x1121BE), Color(hex: 0x0833C4)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(0.76)
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: 0x010428).opacity(0.5), location: 0),
                        .init(color: .clear, location: 0.45),
                        .init(color: Color(hex: 0x2A4FE6).opacity(0.26), location: 0.82),
                        .init(color: Color(hex: 0x3F64F2).opacity(0.3), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                LinearGradient(
                    stops: [
                        .init(color: Self.fog.opacity(0), location: 0),
                        .init(color: Self.fog.opacity(0.025), location: 0.3),
                        .init(color: Self.fog.opacity(0.07), location: 0.55),
                        .init(color: Self.fog.opacity(0.14), location: 0.8),
                        .init(color: Self.fog.opacity(0.22), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: Self.fogHeight)
                .frame(maxHeight: .infinity, alignment: .bottom)
                ForEach(Self.banks.indices, id: \.self) { index in
                    let bank = Self.banks[index]
                    Ellipse()
                        .fill(Self.fog.opacity(bank.opacity))
                        .frame(width: size.width * bank.width, height: bank.height)
                        .position(x: size.width * bank.x, y: size.height + 10)
                        .blur(radius: 14)
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

// Hopping dots, then the step it is on in shimmering caption text. A new step rises in over the
// old one as it fades.
struct ThinkingLine: View {
    let step: String?

    var body: some View {
        HStack(spacing: 10) {
            HoppingDots(color: Palette.textSecondary)
            if let step {
                ZStack(alignment: .leading) {
                    Text(step)
                        .textStyle(.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .shimmering()
                        .id(step)
                        .transition(.asymmetric(insertion: .offset(y: 6).combined(with: .opacity), removal: .opacity))
                }
            }
        }
        .animation(.easeOut(duration: 0.25), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(step ?? "Working")
    }
}

// Why something didn't work, with the one thing that fixes it as a chip, and an optional × to put
// the line away.
struct FailureNote: View {
    let message: String
    var actionTitle: String = "Try again"
    let action: () -> Void
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.textTertiary)
                .accessibilityHidden(true)
            Text(message)
                .textStyle(.caption)
                .lineSpacing(4)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Chip(title: actionTitle, selected: false, action: action)
                .fixedSize()
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .background { Circle().fill(.white.opacity(0.07)) }
                        .overlay { Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1) }
                        .frame(width: ControlHeight.minTouch, height: ControlHeight.minTouch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(IconPressStyle())
                .accessibilityLabel("Dismiss")
            }
        }
    }
}

// Round icon buttons shrink a little while pressed.
struct IconPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(Motion.iconPress, value: configuration.isPressed)
    }
}
