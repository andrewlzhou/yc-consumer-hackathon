import SwiftUI

struct HomeView: View {
    @Binding var report: Bool
    // Set by the `-autoReveal YES` launch argument; runs the demo once, then clears.
    @Binding var autoReveal: Bool
    @State private var phase: Phase = .ready
    @State private var progress = 0.0
    private enum Phase: Equatable { case ready, analyzing, reveal }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CHECK PRICE").font(.system(size: 13, weight: .bold, design: .rounded)).tracking(1.6).foregroundStyle(AppColor.electric)
                        Text("Shop with a signal.").font(.system(size: 30, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    Image(systemName: "person.crop.circle").font(.system(size: 30))
                }
                if phase == .ready { capture }
                if phase == .analyzing { analysis }
                if phase == .reveal { verdict.transition(.scale.combined(with: .opacity)) }
                recent
            }.padding(.bottom, 106)
        }
        .onAppear { if autoReveal { autoReveal = false; start() } }
    }

    private var capture: some View {
        Card {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "hand.tap.fill").font(.system(size: 34)).foregroundStyle(AppColor.electric).symbolEffect(.pulse, options: .repeating)
                Text("See a price you like?").font(.system(size: 25, weight: .bold, design: .rounded))
                Text("Double-tap the back of your phone. We’ll check whether it’s a real deal without taking you out of what you’re doing.").font(.subheadline).foregroundStyle(AppColor.muted).lineSpacing(4)
                Button(action: start) { Label("Try the reveal", systemImage: "sparkles").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 16).background(AppColor.electric, in: Capsule()) }
            }
        }
    }

    private var analysis: some View {
        Card {
            VStack(alignment: .leading, spacing: 20) {
                HStack { Badge("ANALYZING", color: AppColor.electric); Spacer(); Text("\(Int(progress * 45))s").foregroundStyle(AppColor.muted).monospacedDigit() }
                HStack(spacing: 14) {
                    Image(systemName: Demo.headphones.icon).font(.system(size: 26)).frame(width: 48, height: 48).background(AppColor.soft, in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) { Text(Demo.headphones.name).font(.headline); Text("Screenshot captured").font(.subheadline).foregroundStyle(AppColor.muted) }
                }
                VStack(alignment: .leading, spacing: 10) { Text(step).font(.system(size: 20, weight: .bold, design: .rounded)); ProgressView(value: progress).tint(AppColor.electric).scaleEffect(y: 1.7) }
                Text("You can keep scrolling — we’ll tap you when it’s ready.").font(.footnote).foregroundStyle(AppColor.muted)
            }
        }
    }

    private var verdict: some View {
        Card {
            VStack(alignment: .leading, spacing: 20) {
                HStack { Badge("WAIT", color: .yellow); Spacer(); Image(systemName: "sparkles").foregroundStyle(.yellow).symbolEffect(.bounce, value: phase) }
                Text("Wait.").font(.system(size: 48, weight: .heavy, design: .rounded))
                Text(Demo.headphones.summary).font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundStyle(.yellow)
                Divider().overlay(.white.opacity(0.12))
                HStack { Metric(title: "TODAY", value: Demo.headphones.price); Spacer(); Metric(title: "PREDICTED LOW", value: Demo.headphones.projectedLow) }
                Button { report = true } label: { HStack { Text("See the signal"); Spacer(); Image(systemName: "arrow.up.right") }.font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.black).padding(.horizontal, 18).padding(.vertical, 15).background(.white, in: Capsule()) }
            }
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("RECENT SIGNALS").font(.system(size: 12, weight: .bold, design: .rounded)).tracking(1.3).foregroundStyle(AppColor.muted)
            ForEach(Demo.saved) { SignalRow(product: $0) { report = true } }
        }
    }

    private var step: String { progress < 0.34 ? "Finding the product…" : progress < 0.67 ? "Reading 2 years of prices…" : "Picking the best store…" }
    private func start() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { phase = .analyzing }
        withAnimation(.easeInOut(duration: 3.4)) { progress = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { withAnimation(.spring(response: 0.58, dampingFraction: 0.75)) { phase = .reveal } }
    }
}
