// Target membership: widget extension only.
// The pop-up's art: a still version of Worldscape's blue. Two sources:
// - the login intro's "wisps of swirling light" (worldscape apps/macos/.../Login/LoginIntro.swift
//   and GrainGradient/GrainGradientShader.swift: glow #436FFF → iris #4A56FF → ultramarine #1500FF),
// - the input bar the owner pointed at (BarSurface.swift, copied in CheckPrice/DesignSystem/
//   AskParts.swift as `InputBarSurface`): navy-to-royal body, dark top, light rising from the
//   bottom edge, fog along the bottom.
// Live Activities can't run Metal, TimelineView or looping animations, so the wisps are blurred
// ellipses whose pose comes from `phase`. Each update moves them and iOS animates the change.
// A decided verdict keeps the same art in its own hue (yellow for Buy Later).
import SwiftUI

struct WispPalette: Equatable {
    var deep: Color        // body, left
    var mid: Color         // body, middle
    var far: Color         // body, right
    var shade: Color       // darkens the top
    var lift: Color        // light rising from the bottom
    var liftBright: Color  // brightest light, along the bottom edge
    var fog: Color         // wisps and bottom fog
    var rim: Color         // Dynamic Island keyline
    var ink: Color         // the word on the black pill (compact view)

    // Worldscape's input bar, exactly (AskParts.swift `InputBarSurface`).
    static let checking = WispPalette(
        deep: rgb(0x0E0FA2), mid: rgb(0x1121BE), far: rgb(0x0833C4), shade: rgb(0x010428),
        lift: rgb(0x2A4FE6), liftBright: rgb(0x3F64F2), fog: rgb(0xDDE6FF), rim: rgb(0x6B88FF),
        ink: Color.white.opacity(0.94))

    // The same structure re-hued per verdict. Hand-picked, dark enough under white text; the
    // bright stops end on the app's verdict colours (VerdictStyle.swift), except Buy Later,
    // which the owner asked to be yellow rather than the app's amber.
    static func decided(_ verdict: IslandVerdict) -> WispPalette {
        switch verdict {
        case .wait: WispPalette(
            deep: rgb(0x8A5F00), mid: rgb(0xA67A00), far: rgb(0xB08600), shade: rgb(0x2B1A00),
            lift: rgb(0xF0B820), liftBright: rgb(0xFFD23F), fog: rgb(0xFFF3C9), rim: rgb(0xFFD45C),
            ink: rgb(0xFFD23F))
        case .buyNow: WispPalette(
            deep: rgb(0x06573A), mid: rgb(0x0A7048), far: rgb(0x0B7A52), shade: rgb(0x01140C),
            lift: rgb(0x22B877), liftBright: rgb(0x3DDC97), fog: rgb(0xDCFFEE), rim: rgb(0x6BEAB4),
            ink: rgb(0x3DDC97))
        case .alternative: WispPalette(
            deep: rgb(0x3A2490), mid: rgb(0x4A31AD), far: rgb(0x5638B8), shade: rgb(0x0C0628),
            lift: rgb(0x8E72F0), liftBright: rgb(0xC4A7FF), fog: rgb(0xEEE7FF), rim: rgb(0xB8A0FF),
            ink: rgb(0xC4A7FF))
        case .investigate: WispPalette(
            deep: rgb(0x8A3214), mid: rgb(0xA8441E), far: rgb(0xB44E26), shade: rgb(0x260B02),
            lift: rgb(0xF07A4A), liftBright: rgb(0xFF9466), fog: rgb(0xFFE8DC), rim: rgb(0xFFAA85),
            ink: rgb(0xFF9466))
        }
    }

    static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255,
              green: Double((hex >> 8) & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255)
    }
}

struct WispField: View {
    let palette: WispPalette
    let phase: Int

    // Resting place of each wisp, as fractions of the field: centre, size, tilt, opacity, and
    // whether it is fog (pale) or bright light.
    private struct Wisp {
        var x, y, width, height, angle, opacity: Double
        var bright = false
    }

    private static let wisps: [Wisp] = [
        Wisp(x: 0.22, y: 0.60, width: 0.55, height: 0.22, angle: -12, opacity: 0.16),
        Wisp(x: 0.64, y: 0.36, width: 0.60, height: 0.18, angle: 8, opacity: 0.12),
        Wisp(x: 0.86, y: 0.76, width: 0.50, height: 0.30, angle: -6, opacity: 0.20),
        Wisp(x: 0.42, y: 0.88, width: 0.70, height: 0.26, angle: 4, opacity: 0.38, bright: true),
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(colors: [palette.deep, palette.mid, palette.far],
                               startPoint: .leading, endPoint: .trailing)
                LinearGradient(
                    stops: [
                        .init(color: palette.shade.opacity(0.5), location: 0),
                        .init(color: .clear, location: 0.45),
                        .init(color: palette.lift.opacity(0.26), location: 0.82),
                        .init(color: palette.liftBright.opacity(0.3), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom)
                ForEach(0..<Self.wisps.count, id: \.self) { index in
                    wisp(index, in: size)
                }
                bottomGlow(in: size)
                LinearGradient(
                    stops: [
                        .init(color: palette.fog.opacity(0), location: 0),
                        .init(color: palette.fog.opacity(0.025), location: 0.3),
                        .init(color: palette.fog.opacity(0.07), location: 0.55),
                        .init(color: palette.fog.opacity(0.14), location: 0.8),
                        .init(color: palette.fog.opacity(0.22), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom)
            }
            // iOS caps Live Activity animations at about 2 seconds.
            .animation(.easeInOut(duration: 1.8), value: phase)
            .animation(.easeInOut(duration: 1.2), value: palette)
        }
        .accessibilityHidden(true)
    }

    // A soft, tilted streak that drifts a little with each phase.
    private func wisp(_ index: Int, in size: CGSize) -> some View {
        let w = Self.wisps[index]
        let p = Double(phase)
        let i = Double(index)
        let dx = 0.07 * sin(p * 1.1 + i * 2.3)
        let dy = 0.08 * cos(p * 0.8 + i * 1.9)
        let tilt = w.angle + 10 * sin(p * 0.7 + i)
        return Ellipse()
            .fill(w.bright ? palette.liftBright : palette.fog)
            .frame(width: size.width * w.width, height: size.height * w.height)
            .rotationEffect(.degrees(tilt))
            .blur(radius: max(size.height * 0.12, 1.5))
            .opacity(w.opacity)
            .position(x: size.width * (w.x + dx), y: size.height * (w.y + dy))
    }

    // The brighter glow along the bottom edge, as on the input bar.
    private func bottomGlow(in size: CGSize) -> some View {
        Ellipse()
            .fill(palette.liftBright)
            .frame(width: size.width * 0.9, height: size.height * 0.5)
            .blur(radius: max(size.height * 0.22, 2))
            .opacity(0.5)
            .position(x: size.width * (0.5 + 0.05 * sin(Double(phase) * 0.9)), y: size.height * 1.02)
    }
}
