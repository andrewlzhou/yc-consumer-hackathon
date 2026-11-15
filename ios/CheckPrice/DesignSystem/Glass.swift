// Copied from notyet/ios/Views/DesignSystem/Glass.swift (Not Yet).
// Glass and the blue light it sits on (worldscape F/World/WorldCard.swift `CardGlass`,
// design-system.md). Glass is always layered, never a bare material: a blurred shadow shape, a
// frost, a top sheen, and a hairline brightest on top. iOS materials only blur the app's own
// content, so glass over the plain canvas reads as flat grey: put it over `BackdropGradient`.
import SwiftUI

struct GlassSurface: View {
    var cornerRadius: CGFloat = Radius.glassCard
    // Lit: brighter and lifted. On iOS this is the pressed (or selected) state.
    var isLit = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            // A soft deep-blue shadow, drawn as a blurred shape rather than `.shadow`.
            shape
                .fill(Color(hex: 0x030836).opacity(isLit ? 0.42 : 0.3))
                .blur(radius: isLit ? 20 : 15)
                .offset(y: isLit ? 14 : 9)
            // Frosts the light behind it, as glass would.
            if reduceTransparency {
                shape.fill(
                    LinearGradient(colors: [Color(hex: 0x12173A), Color(hex: 0x0B0C12)], startPoint: .topLeading, endPoint: .bottomTrailing)
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

// The blue light behind glass. Worldscape draws it with a Metal shader with grain; this is a
// still approximation (glow → iris → ultramarine meeting the dark), with no grain or drift.
// Judge it by eye. It fills its space and ignores safe areas.
struct BackdropGradient: View {
    enum Style {
        // iOS 18 mesh: light pooling in the lower half, dark at the top.
        case mesh
        // A plain top-to-bottom gradient, cheapest to draw.
        case linear
    }

    var style: Style = .mesh

    var body: some View {
        Group {
            switch style {
            case .mesh:
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        [0, 0], [0.5, 0], [1, 0],
                        [0, 0.55], [0.6, 0.5], [1, 0.6],
                        [0, 1], [0.5, 1], [1, 1],
                    ],
                    colors: [
                        Palette.canvas, Palette.canvas, Palette.canvas,
                        Palette.ultramarine, Palette.iris, Color(hex: 0x0A1BA8),
                        Palette.electric, Palette.glow, Palette.iris,
                    ]
                )
            case .linear:
                LinearGradient(
                    stops: [
                        .init(color: Palette.canvas, location: 0),
                        .init(color: Palette.ultramarine, location: 0.5),
                        .init(color: Palette.iris, location: 0.8),
                        .init(color: Palette.glow, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
}
