// Home's aurora, after Worldscape's world light (worldscape Features/World/WorldBackdrop.swift and
// WorldLightShader.swift): soft blobs of light drifting slowly under silky folds, with fine grain,
// never a flat gradient. Worldscape draws it in Metal; this is SwiftUI only (TimelineView + Canvas):
// radial-gradient blobs in the warm palette (accent orange, cream, stone) on the canvas, a few
// blurred sine bands with a thin bright crest for the folds, a tiled noise image for grain, and the
// top darkened so the headline stays readable. The light pools in the lower half. A full drift takes
// about a minute. While a check runs (`isActive`) the light brightens and moves about twice as fast,
// easing back after. Under Reduce Motion it is one still frame.
import SwiftUI

struct HomeAurora: View {
    var isActive = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = AuroraClock()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let state = reduceMotion ? (phase: 40.0, level: 0.0) : clock.advance(to: timeline.date, active: isActive)
                Self.draw(&context, size: size, t: state.phase, level: state.level)
            }
        }
        .overlay { AuroraGrain() }
        .overlay {
            // Dark at the top, so the light gathers low and the headline reads.
            LinearGradient(
                stops: [
                    .init(color: Palette.canvas.opacity(0.92), location: 0),
                    .init(color: Palette.canvas.opacity(0.55), location: 0.3),
                    .init(color: .clear, location: 0.62),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .background(Palette.canvas)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct Blob {
        let home: CGPoint      // resting centre, as fractions of the screen
        let radius: CGFloat    // as a fraction of the screen's height
        let color: Color
        let opacity: Double
        let speed: Double
    }

    private static let accent = Palette.accent
    private static let cream = Color(hex: 0xFAF9F5)
    private static let stone = Palette.stone

    private static let blobs: [Blob] = [
        Blob(home: CGPoint(x: 0.25, y: 0.78), radius: 0.42, color: stone, opacity: 0.55, speed: 0.9),
        Blob(home: CGPoint(x: 0.78, y: 0.88), radius: 0.38, color: accent, opacity: 0.34, speed: 1.1),
        Blob(home: CGPoint(x: 0.55, y: 0.62), radius: 0.30, color: cream, opacity: 0.08, speed: 0.7),
        Blob(home: CGPoint(x: 0.12, y: 0.98), radius: 0.34, color: accent, opacity: 0.22, speed: 1.3),
        Blob(home: CGPoint(x: 0.9, y: 0.55), radius: 0.28, color: stone, opacity: 0.35, speed: 0.8),
    ]

    private static func draw(_ context: inout GraphicsContext, size: CGSize, t: Double, level: Double) {
        let w = size.width, h = size.height
        let glow = 1 + 0.6 * level

        // Blobs, each on its own slow loop, slightly flattened so they read as low light.
        for (i, blob) in blobs.enumerated() {
            let fi = Double(i)
            let x = blob.home.x + 0.16 * sin(t * 0.09 * blob.speed + fi * 1.9)
            let y = blob.home.y + 0.07 * cos(t * 0.07 * blob.speed + fi * 2.7)
            let r = blob.radius * h
            var layer = context
            layer.translateBy(x: x * w, y: y * h)
            layer.scaleBy(x: 1, y: 0.72)
            layer.fill(
                Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)),
                with: .radialGradient(
                    Gradient(colors: [blob.color.opacity(min(1, blob.opacity * glow)), blob.color.opacity(0)]),
                    center: .zero, startRadius: 0, endRadius: r
                )
            )
        }

        // Folds: broad soft bands across the lower half, each with a thin crest catching the light.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 26))
            for i in 0..<3 {
                let band = fold(index: i, size: size, t: t)
                layer.stroke(band, with: .color(cream.opacity(0.045 * glow)), lineWidth: h * 0.09)
            }
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 3))
            for i in 0..<3 {
                let band = fold(index: i, size: size, t: t)
                layer.stroke(band, with: .color(cream.opacity(0.07 * glow)), lineWidth: 1.5)
            }
        }
    }

    // One fold: a gentle wave across the screen, its height and sway set by its index.
    private static func fold(index i: Int, size: CGSize, t: Double) -> Path {
        let fi = Double(i)
        let baseY = size.height * (0.6 + 0.11 * fi)
        let amplitude = size.height * (0.035 + 0.012 * fi)
        let wavelength = size.width * (1.3 + 0.35 * fi)
        let drift = t * (0.12 + 0.03 * fi) + fi * 2.1
        let tilt = size.height * 0.05 * sin(t * 0.03 + fi)
        var path = Path()
        let step: CGFloat = 12
        var x: CGFloat = -step
        while x <= size.width + step {
            let y = baseY + amplitude * sin(Double(x / wavelength) * 2 * .pi + drift) + tilt * (x / size.width - 0.5)
            if x < 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            x += step
        }
        return path
    }
}

// Integrates time so the speed can change without the light jumping, and eases the active level
// toward its target. A plain class: it changes during drawing and must not trigger a redraw.
private final class AuroraClock {
    // Starts partway along, as Worldscape's does, so the first look isn't a resting pose.
    private var phase = 40.0
    private var level = 0.0
    private var last: Date?

    func advance(to date: Date, active: Bool) -> (phase: Double, level: Double) {
        let dt = min(max(date.timeIntervalSince(last ?? date), 0), 0.1)
        last = date
        level += ((active ? 1 : 0) - level) * min(1, dt * 1.5)
        phase += dt * (1 + level)
        return (phase, level)
    }
}

// Fine grain over the light: a small tile of random speckles, made once and repeated.
private struct AuroraGrain: View {
    // 256 x 256 grey pixels shown at 3x, so each speckle is one device pixel on most iPhones.
    private static let tile: UIImage = {
        let side = 256
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<side * side).map { _ in UInt8.random(in: 0...255, using: &generator) }
        let provider = CGDataProvider(data: Data(bytes) as CFData)
        guard let provider,
              let image = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: side,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return UIImage() }
        return UIImage(cgImage: image, scale: 3, orientation: .up)
    }()

    var body: some View {
        Image(uiImage: Self.tile)
            .resizable(resizingMode: .tile)
            .blendMode(.overlay)
            .opacity(0.07)
    }
}
