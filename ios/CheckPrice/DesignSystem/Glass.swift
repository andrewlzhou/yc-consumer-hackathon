// Copied from notyet/ios/Views/DesignSystem/Glass.swift (Not Yet).
// Glass (worldscape F/World/WorldCard.swift `CardGlass`, design-system.md). Glass is always
// layered, never a bare material: a blurred shadow shape, a frost, a top sheen, and a hairline
// brightest on top. iOS materials only blur the app's own content, so over the flat canvas it reads
// as a soft grey panel, which suits the warm-neutral palette.
import SwiftUI

struct GlassSurface: View {
    var cornerRadius: CGFloat = Radius.glassCard
    // Lit: brighter and lifted. On iOS this is the pressed (or selected) state.
    var isLit = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            // A soft dark shadow, drawn as a blurred shape rather than `.shadow`.
            shape
                .fill(Color.black.opacity(isLit ? 0.42 : 0.3))
                .blur(radius: isLit ? 20 : 15)
                .offset(y: isLit ? 14 : 9)
            // Frosts the light behind it, as glass would.
            if reduceTransparency {
                shape.fill(
                    LinearGradient(colors: [Color(hex: 0x2A2926), Color(hex: 0x1A1917)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            } else {
                shape
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .light)
                    .opacity(0.4)
            }
            // A pale wash, brighter at the top.
            shape.fill(
                LinearGradient(
                    colors: [.white.opacity(isLit ? 0.16 : 0.11), .white.opacity(isLit ? 0.07 : 0.035)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            // A hairline that catches the light along the top edge.
            shape.strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(isLit ? 0.52 : 0.4), .white.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
        .animation(.easeOut(duration: 0.2), value: isLit)
    }
}

extension View {
    // Puts glass behind the view: `VStack { … }.padding(16).glassSurface()`.
    func glassSurface(cornerRadius: CGFloat = Radius.glassCard, isLit: Bool = false) -> some View {
        background { GlassSurface(cornerRadius: cornerRadius, isLit: isLit) }
    }
}

// A tappable glass card: the glass lights and the card dips to 0.975 while pressed.
struct GlassCardButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = Radius.glassCard

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassSurface(cornerRadius: cornerRadius, isLit: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(Motion.cardPress, value: configuration.isPressed)
    }
}
