// Target membership: app only.
// Buttons as physical keys lit from above (worldscape DS/Buttons.swift). Pressing sinks the face
// onto its darker side and tightens the shadows; colours never change. iOS: hover states are
// dropped, a light haptic marks the press, and every key keeps a 44pt hit area.
import SwiftUI

// The pressable key. `.primary` is the one blue action on a screen; `.secondary` is a small dark
// key for actions inside lists, quiet beside the blue one.
struct KeyButtonStyle: ButtonStyle {
    enum Tone { case primary, secondary }

    var tone: Tone = .primary
    // Visual height. Primary defaults to the 50pt main-action size; secondary to 36pt.
    var height: CGFloat?
    // Swaps the label for a spinner while keeping the key's size.
    var isWorking = false

    func makeBody(configuration: Configuration) -> some View {
        KeyButton(
            configuration: configuration,
            tone: tone,
            height: height ?? (tone == .primary ? ControlHeight.mainKey : ControlHeight.smallKey),
            isWorking: isWorking
        )
    }
}

// A full-width outlined key for another way to do the same thing. Flat and outlined like a field,
// so the blue key stays the one to press.
struct QuietButtonStyle: ButtonStyle {
    var height: CGFloat = ControlHeight.quietKey
    var isWorking = false

    func makeBody(configuration: Configuration) -> some View {
        QuietButton(configuration: configuration, height: height, isWorking: isWorking)
    }
}

private struct KeyButton: View {
    let configuration: ButtonStyleConfiguration
    let tone: KeyButtonStyle.Tone
    let height: CGFloat
    let isWorking: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let isPressed = configuration.isPressed
        let depth: CGFloat = tone == .primary ? 2 : 1.5
        let radius = tone == .primary ? Radius.key : Radius.smallKey
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        // Short keys get invisible padding so the hit area is at least 44pt tall.
        let hitPadding = max(0, (ControlHeight.minTouch - height - depth) / 2)

        // The label sizes the key: full width for primary, hugging the label for secondary.
        // The face moves with the label; the base stays put, `depth` below it.
        label
            .frame(maxWidth: tone == .primary ? CGFloat.infinity : nil)
            .frame(height: height)
            .background { KeyFace(tone: tone, shape: shape, isPressed: isPressed) }
            .offset(y: isPressed ? depth : 0)
            .background {
                KeyBase(tone: tone, shape: shape, isPressed: isPressed)
                    .offset(y: depth)
            }
            .padding(.bottom, depth)
            .opacity(isEnabled ? 1 : 0.5)
            .padding(.vertical, hitPadding)
            .contentShape(Rectangle())
            // Sink quickly, then spring back like a key returning.
            .animation(isPressed ? Motion.pressDown : Motion.pressRelease, value: isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: isPressed) { _, pressed in pressed }
    }

    private var label: some View {
        ZStack {
            Group {
                if tone == .primary {
                    configuration.label
                        .textStyle(.button)
                        .foregroundStyle(.white)
                        .dropShadow(Shadows.labelOnBlue)
                } else {
                    configuration.label
                        .textStyle(.smallButton)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.horizontal, 14)
                }
            }
            .lineLimit(1)
            .opacity(isWorking ? 0 : 1)
            if isWorking {
                WorkingIndicator(size: tone == .primary ? 15 : 12)
            }
        }
    }
}

// The lit top surface. Its fill never changes; pressing only shades its top edge.
private struct KeyFace: View {
    let tone: KeyButtonStyle.Tone
    let shape: RoundedRectangle
    let isPressed: Bool

    var body: some View {
        switch tone {
        case .primary:
            ZStack {
                shape.fill(
                    LinearGradient(
                        colors: [Color(hex: 0x2A78FF), Palette.electric, Color(hex: 0x0052E3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .shadow(.inner(color: Color(hex: 0x1B6FFF), radius: 2.7, x: 1, y: 5))
                )
                // A soft sheen across the upper half shows the face is gently domed.
                shape.fill(
                    LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0)], startPoint: .top, endPoint: .center)
                )
                InsetShadow(shape: shape, color: Color(hex: 0x001A6B, opacity: 0.32), radius: 2.5, y: -1.5)
                InsetShadow(shape: shape, color: .black.opacity(0.36), radius: 3, y: 2)
                    .opacity(isPressed ? 1 : 0)
            }
        case .secondary:
            ZStack {
                shape.fill(LinearGradient(colors: [Color(hex: 0x34343A), Color(hex: 0x24242A)], startPoint: .top, endPoint: .bottom))
                InsetShadow(shape: shape, color: .white.opacity(0.14), radius: 0.6, y: 1)
                InsetShadow(shape: shape, color: .black.opacity(0.4), radius: 2, y: 1.5)
                    .opacity(isPressed ? 1 : 0)
                shape.strokeBorder(.white.opacity(0.06), lineWidth: 1)
            }
        }
    }
}

// The key's darker side and the shadows it casts. Raised, the side shows as a band below the
// face; pressed, the face covers it and the shadows tighten to the key's footprint.
private struct KeyBase: View {
    let tone: KeyButtonStyle.Tone
    let shape: RoundedRectangle
    let isPressed: Bool

    var body: some View {
        switch tone {
        case .primary:
            shape
                .fill(LinearGradient(colors: [Color(hex: 0x0048CC), Color(hex: 0x00309A)], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.45), radius: isPressed ? 0.5 : 1, y: isPressed ? 0.5 : 1)
                .shadow(color: .black.opacity(isPressed ? 0.18 : 0.3), radius: isPressed ? 1.5 : 6, y: isPressed ? 0.5 : 4)
                .shadow(color: Palette.electric.opacity(isPressed ? 0.1 : 0.2), radius: isPressed ? 4 : 12, y: isPressed ? 1 : 6)
        case .secondary:
            shape
                .fill(Color(hex: 0x111114))
                .shadow(color: .black.opacity(isPressed ? 0.3 : 0.55), radius: isPressed ? 1 : 3, y: isPressed ? 0.5 : 2)
        }
    }
}

private struct QuietButton: View {
    let configuration: ButtonStyleConfiguration
    let height: CGFloat
    let isWorking: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        // The Mac hover look is the iOS pressed look.
        let lit = configuration.isPressed && isEnabled
        ZStack {
            RoundedRectangle(cornerRadius: Radius.key, style: .continuous)
                .fill(.white.opacity(lit ? 0.04 : 0))
            FieldBorder(isPressed: lit)
            configuration.label
                .textStyle(.button)
                .foregroundStyle(lit ? Palette.textPrimary : Palette.textSecondary)
                .lineLimit(1)
                .opacity(isWorking ? 0 : 1)
            if isWorking {
                WorkingIndicator()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .opacity(isEnabled ? 1 : 0.5)
        .contentShape(Rectangle())
        .animation(Motion.hover, value: lit)
    }
}

// An inner shadow from ordinary view effects: a thick outline, shifted, blurred, and kept inside
// the shape. Animating SwiftUI's inner-shadow fill styles can turn the whole fill white, so state
// changes only fade these layers in and out.
struct InsetShadow<S: Shape>: View {
    let shape: S
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    var body: some View {
        shape
            .stroke(color, lineWidth: radius * 2 + abs(y) * 2)
            .offset(y: y)
            .blur(radius: radius)
            .mask(shape)
    }
}
