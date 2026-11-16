// The app's backdrop, behind every tab and every pushed or presented screen (owner, 2026-11-15:
// "apply the gradient background to all pages"). One still frame of what was Home's aurora, after
// Worldscape's world light (worldscape Features/World/WorldBackdrop.swift and WorldLightShader.swift):
// soft blobs of light in the warm palette (accent orange, cream, stone) on the canvas, a few blurred
// bands with a thin bright crest for folds, fine grain, and the top darkened. The light pools in the
// lower half. It does not move: the drifting version was dropped with the old Home.
import SwiftUI

struct AppBackdrop: View {
    var body: some View {
        Canvas { context, size in Self.draw(&context, size: size) }
            .overlay { BackdropGrain() }
            .overlay {
                // Dark at the top, so the light gathers low.
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

    // How strong the light is, 1 being the aurora as first drawn. At 0.7, secondary text
    // (`Palette.textSecondary`) on a `FlatCard` keeps at least 4.5:1 contrast over the brightest
    // spot (estimated from these blobs, not measured on a device); at 1 it fell to about 3.8:1.
    static let strength = 0.7

    // Where the frame sits in the old drift, which ran from 40 (Worldscape starts partway along).
    private static let phase = 40.0

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

    private static func draw(_ context: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height, t = phase

        // Blobs, each moved off its centre by where it was in the drift, slightly flattened so they
        // read as low light.
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
                    Gradient(colors: [blob.color.opacity(blob.opacity * strength), blob.color.opacity(0)]),
                    center: .zero, startRadius: 0, endRadius: r
                )
            )
        }

        // Folds: broad soft bands across the lower half, each with a thin crest catching the light.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 26))
            for i in 0..<3 {
                layer.stroke(fold(index: i, size: size), with: .color(cream.opacity(0.045 * strength)), lineWidth: h * 0.09)
            }
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 3))
            for i in 0..<3 {
                layer.stroke(fold(index: i, size: size), with: .color(cream.opacity(0.07 * strength)), lineWidth: 1.5)
            }
        }
    }

    // One fold: a gentle wave across the screen, its height and sway set by its index.
    private static func fold(index i: Int, size: CGSize) -> Path {
        let fi = Double(i), t = phase
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

// Fine grain over the light: a small tile of random speckles, made once and repeated.
private struct BackdropGrain: View {
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
