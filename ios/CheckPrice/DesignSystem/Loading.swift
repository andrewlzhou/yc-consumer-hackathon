// Copied from notyet/ios/Views/DesignSystem/Loading.swift (Not Yet).
// Waiting and streaming states (worldscape F/Chat/MessageColumn.swift, DS/Buttons.swift).
// Reduce Motion turns the shimmer off.
import SwiftUI
import UIKit

// Three dots hopping in turn while an answer is on its way: 6pt dots, 4.5pt apart, each hopping
// 3.5pt with a 0.15s stagger on a 1.2s cycle.
struct HoppingDots: View {
    var color: Color = .white

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4.5) {
                ForEach(0..<3, id: \.self) { index in
                    let hop = Self.hop(at: time - Double(index) * 0.15)
                    Circle()
                        .fill(color.opacity(0.4 + 0.5 * hop))
                        .frame(width: 6, height: 6)
                        .offset(y: -3.5 * hop)
                }
            }
            .frame(height: 14)
        }
        .padding(.horizontal, 2)
        .accessibilityElement()
        .accessibilityLabel("Working")
    }

    // 0 at rest, 1 at the top of a quick hop that repeats every 1.2 seconds.
    private static func hop(at time: TimeInterval) -> Double {
        let phase = time.truncatingRemainder(dividingBy: 1.2) / 1.2
        return phase < 0.42 ? sin(phase / 0.42 * .pi) : 0
    }
}

// A band of light sweeping across text that is still in progress: white 55%, half the text's
// width, every 1.8s, masked to the text.
private struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            TimelineView(.animation) { context in
                let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8
                content
                    .overlay {
                        GeometryReader { proxy in
                            LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(width: proxy.size.width * 0.5)
                                .offset(x: (phase * 1.5 - 0.5) * proxy.size.width)
                        }
                        .mask(content)
                        .blendMode(.plusLighter)
                    }
            }
        }
    }
}

extension View {
    // `Text("Checking prices").shimmering()`; pass false to turn it off.
    @ViewBuilder func shimmering(_ isOn: Bool = true) -> some View {
        if isOn { modifier(Shimmer()) } else { self }
    }
}

// Text that grows behind an inline caret of glow while it streams in. The caret follows the last
// word onto new lines; words don't cross-fade. Drop the caret when streaming ends.
struct StreamingText: View {
    let text: String
    var isStreaming: Bool

    init(_ text: String, isStreaming: Bool) {
        self.text = text
        self.isStreaming = isStreaming
    }

    var body: some View {
        Group {
            if isStreaming {
                Text("\(Text(verbatim: text))\(StreamingCaret.image)")
            } else {
                Text(verbatim: text)
            }
        }
        .contentTransition(.identity)
        .animation(Motion.streamReflow, value: text)
    }
}

// A slim 2pt bar of glow with its own gap before it, drawn as an image so it sits inline in text
// without making its line taller.
@MainActor
enum StreamingCaret {
    static let image: Image = {
        let size = CGSize(width: 5, height: 13)
        let renderer = UIGraphicsImageRenderer(size: size)
        let uiImage = renderer.image { _ in
            UIColor(red: 0x43 / 255, green: 0x6F / 255, blue: 0xFF / 255, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 3, y: 0, width: 2, height: size.height), cornerRadius: 1).fill()
        }
        return Image(uiImage: uiImage)
    }()
}

// A 1.75pt arc spinning once every 0.8s, for keys that are working.
struct WorkingIndicator: View {
    var size: CGFloat = 15
    var color: Color = .white
    @State private var isSpinning = false

    var body: some View {
        Circle()
            .trim(from: 0.12, to: 0.82)
            .stroke(color, style: StrokeStyle(lineWidth: 1.75, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: isSpinning)
            .onAppear { isSpinning = true }
            .accessibilityLabel("Working")
    }
}
