// Home's first screen: the app's main function, capture → analyzing → verdict reveal. Self-contained so the final animation (not decided yet) can replace it whole.
// The run is a demo on `Demo.headphones`; nothing is captured or analysed.
import SwiftUI

struct PrimaryCheckArea: View {
    // Set by the `-autoReveal YES` launch argument; runs the demo once, then clears.
    @Binding var autoReveal: Bool
    @Environment(ThreadStore.self) private var store
    @State private var phase: Phase = .ready
    @State private var progress = 0.0
    @State private var threadID: UUID?
    // Flips once the reveal is on screen, so its parts can rise in one after another.
    @State private var arrived = false

    private enum Phase { case ready, analyzing, reveal }
    private let product = Demo.headphones

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenTitle("Check Price")
            Spacer(minLength: Spacing.titleToForm)
            switch phase {
            case .ready: ready.transition(.rise)
            case .analyzing: analyzing.transition(.rise)
            case .reveal: reveal
            }
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .onAppear {
            if autoReveal { autoReveal = false; start() }
        }
    }

    // MARK: Ready

    private var ready: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "hand.tap")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Palette.textSecondary)
                .symbolEffect(.pulse, options: .repeating)
                .accessibilityHidden(true)
                .padding(.bottom, 14)
            Text("See a price you like?")
                .textStyle(.statement(size: 30))
                .foregroundStyle(Palette.textPrimary)
                .padding(.bottom, 12)
            Text("Double-tap the back of your phone. We’ll check whether it’s a real deal without taking you out of what you’re doing.")
                .textStyle(.body)
                .lineSpacing(6)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Spacing.titleToForm)
            Button("Try the reveal", action: start)
                .buttonStyle(KeyButtonStyle())
        }
    }

    // MARK: Analyzing

    private var analyzing: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: Spacing.rowIconToText) {
                    Image(systemName: product.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .frame(width: ControlHeight.avatar, height: ControlHeight.avatar)
                        .background { Circle().fill(.white.opacity(0.1)) }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .textStyle(.cardTitle)
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(2)
                        Text("Screenshot captured")
                            .textStyle(.caption)
                            .foregroundStyle(.white.opacity(0.82))
                    }
                }
                ThinkingLine(step: step)
                ProgressLine(value: progress)
            }
            .padding(.leading, Spacing.cardLeading)
            .padding(.trailing, Spacing.cardLeading)
            .padding(.top, Spacing.cardTop + 4)
            .padding(.bottom, Spacing.cardBottom + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { flatCard }
            Text("You can keep scrolling. We’ll tap you when it’s ready.")
                .textStyle(.footnote)
                .foregroundStyle(.white.opacity(0.68))
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
            Spacer(minLength: 0)
        }
    }

    // MARK: Reveal

    // The verdict arrives in steps: symbol, word, then the details, each rising in with a spring.
    private var reveal: some View {
        let verdict = product.verdict
        return VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            Image(systemName: verdict.symbol)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(verdict.color)
                .symbolEffect(.bounce, value: arrived)
                .accessibilityHidden(true)
                .scaleEffect(arrived ? 1 : 0.4)
                .opacity(arrived ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: arrived)
                .padding(.bottom, 10)
            Text(verdict.word)
                .textStyle(.wordmark(size: 72))
                .foregroundStyle(verdict.color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .modifier(RiseEffect(progress: arrived ? 1 : 0))
                .animation(Motion.cardArrive.delay(0.08), value: arrived)
                .padding(.bottom, 8)
            Text(product.summary)
                .textStyle(.statement(size: 24))
                .lineSpacing(6)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(RiseEffect(progress: arrived ? 1 : 0))
                .animation(Motion.cardArrive.delay(0.18), value: arrived)
            Spacer(minLength: Spacing.titleToForm)
            VStack(spacing: 18) {
                HStack(alignment: .top) {
                    Metric(title: "Today", value: product.price)
                    Spacer()
                    Metric(title: "Predicted low", value: product.projectedLow)
                }
                .padding(.leading, Spacing.cardLeading)
                .padding(.trailing, Spacing.cardLeading)
                .padding(.vertical, 16)
                .background { flatCard }
                Button(action: openThread) {
                    HStack {
                        Text("See the signal")
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.horizontal, 18)
                }
                .buttonStyle(KeyButtonStyle())
            }
            .modifier(RiseEffect(progress: arrived ? 1 : 0))
            .animation(Motion.cardArrive.delay(0.3), value: arrived)
        }
        .onAppear { arrived = true }
    }

    // FlatCard's surface alone. Glass would read as flat grey here: the backdrop's light is only
    // at the top of the screen.
    private var flatCard: some View {
        FlatCard(cornerRadius: Radius.glassCard) { Color.clear }
    }

    private var step: String {
        progress < 0.34 ? "Finding the product…" : progress < 0.67 ? "Reading 2 years of prices…" : "Picking the best store…"
    }

    private func start() {
        withAnimation(Motion.rise) { phase = .analyzing }
        withAnimation(.easeInOut(duration: 3.4)) { progress = 1 }
        // The same run in the pop-up (Live Activity), seen once the user leaves the app.
        Task { await CheckActivity.play(verdict: product.verdict, reason: product.summary, over: 3.5) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            threadID = store.startThread(for: product)
            withAnimation(Motion.screenSwap) { phase = .reveal }
        }
    }

    private func openThread() {
        store.openThreadID = threadID
    }
}

// A thin white line that fills as the check runs.
private struct ProgressLine: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule().fill(.white.opacity(0.9)).frame(width: proxy.size.width * value)
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}
