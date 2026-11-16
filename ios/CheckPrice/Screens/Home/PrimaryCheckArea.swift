// Home's first screen: the app's main function, capture → analyzing → verdict reveal. Self-contained so the final animation (not decided yet) can replace it whole.
// Check price sends a store link on the clipboard, or else a picked screenshot, to the backend
// (Backend/Backend.swift). `-autoReveal YES` runs the demo on `Demo.headphones`; a build without a backend key says so.
import PhotosUI
import ShopperKit
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
    @State private var product = Demo.headphones
    // While analyzing a link: its store's domain, since the product isn't known yet.
    @State private var checkingLabel: String?
    @State private var pickingScreenshot = false
    @State private var screenshot: PhotosPickerItem?
    @State private var failure: String?

    private enum Phase { case ready, analyzing, reveal }

    var body: some View {
        // Each phase is one block, centred vertically in the first screen.
        ZStack(alignment: .leading) {
            switch phase {
            case .ready: ready.transition(.rise)
            case .analyzing: analyzing.transition(.rise)
            case .reveal: reveal
            }
        }
        .padding(.horizontal, Spacing.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .onAppear {
            if autoReveal { autoReveal = false; startDemo() }
        }
        .photosPicker(isPresented: $pickingScreenshot, selection: $screenshot, matching: .screenshots)
        .onChange(of: screenshot) { _, item in
            guard let item else { return }
            screenshot = nil
            Task { await checkScreenshot(item) }
        }
    }

    // MARK: Ready

    private var ready: some View {
        VStack(alignment: .leading, spacing: Spacing.titleToForm) {
            Text("See a price you like?")
                .textStyle(.statement(size: 30))
                .foregroundStyle(Palette.textPrimary)
            Button("Check price", action: start)
                .buttonStyle(KeyButtonStyle())
            if let failure {
                FailureNote(message: failure, action: start, onDismiss: { self.failure = nil })
            }
        }
    }

    // MARK: Analyzing

    private var analyzing: some View {
        VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: Spacing.rowIconToText) {
                    Image(systemName: checkingLabel == nil ? product.icon : "tag")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .frame(width: ControlHeight.avatar, height: ControlHeight.avatar)
                        .background { Circle().fill(.white.opacity(0.1)) }
                    Text(checkingLabel ?? product.name)
                        .textStyle(.cardTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(2)
                }
                ProgressLine(value: progress)
            }
            .padding(.leading, Spacing.cardLeading)
            .padding(.trailing, Spacing.cardLeading)
            .padding(.top, Spacing.cardTop + 4)
            .padding(.bottom, Spacing.cardBottom + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { flatCard }
    }

    // MARK: Reveal

    // The verdict arrives in steps: word, summary, then the numbers, each rising in with a spring.
    private var reveal: some View {
        let verdict = product.verdict
        return VStack(alignment: .leading, spacing: 0) {
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
            VStack(spacing: 18) {
                HStack(alignment: .top) {
                    Metric(title: "Today", value: product.price)
                    Spacer()
                    if !product.projectedLow.isEmpty {
                        Metric(title: "Predicted low", value: product.projectedLow)
                    }
                }
                .padding(.leading, Spacing.cardLeading)
                .padding(.trailing, Spacing.cardLeading)
                .padding(.vertical, 16)
                .background { flatCard }
                Button("Details", action: openThread)
                    .buttonStyle(KeyButtonStyle())
            }
            .padding(.top, Spacing.titleToForm)
            .modifier(RiseEffect(progress: arrived ? 1 : 0))
            .animation(Motion.cardArrive.delay(0.3), value: arrived)
        }
        .onAppear { arrived = true }
    }

    // FlatCard's surface alone. Glass would read as flat grey over the plain canvas.
    private var flatCard: some View {
        FlatCard(cornerRadius: Radius.glassCard) { Color.clear }
    }

    // A store link on the clipboard is checked right away; otherwise the user picks a screenshot.
    private func start() {
        failure = nil
        // No key: say so. A made-up verdict would pass for a real check; the demo runs only from `-autoReveal YES`.
        guard !(Backend.config.apiKey ?? "").isEmpty else {
            failure = ShopperError.notConfigured.message
            return
        }
        if UIPasteboard.general.hasURLs, let url = UIPasteboard.general.url, url.scheme?.hasPrefix("http") == true {
            checkingLabel = url.host()?.replacingOccurrences(of: "www.", with: "")
            run { await CheckRunner.run(url: url) }
        } else {
            pickingScreenshot = true
        }
    }

    private func checkScreenshot(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            failure = ShopperError.unreadableImage.message
            return
        }
        checkingLabel = nil
        run { await CheckRunner.run(imageData: data) }
    }

    // Analyzing while the backend answers (the line fills to 90%, then completes), then the reveal and a
    // new thread, or back to ready with the failure. The pop-up checks alongside and shows the verdict.
    private func run(_ check: @escaping () async -> Result<CheckResult, ShopperError>) {
        product = Product(name: "", retailer: "", price: "", icon: "tag", verdict: .investigate, summary: "", projectedLow: "")
        progress = 0
        withAnimation(Motion.rise) { phase = .analyzing }
        withAnimation(.easeOut(duration: 6)) { progress = 0.9 }
        Task { @MainActor in
            let activity = await CheckActivity.start()
            switch await check() {
            case let .success(result):
                product = result.product
                if let activity {
                    await CheckActivity.decide(activity, verdict: product.verdict, reason: Self.islandReason(product.summary), phase: 1)
                }
                withAnimation(.easeOut(duration: 0.3)) { progress = 1 }
                try? await Task.sleep(for: .seconds(0.3))
                let id = store.startThread(for: product)
                threadID = id
                store.loadReport(for: id)
                arrived = false
                withAnimation(Motion.screenSwap) { phase = .reveal }
            case let .failure(error):
                if let activity { await activity.end(nil, dismissalPolicy: .immediate) }
                failure = error.message
                withAnimation(Motion.rise) { phase = .ready }
            }
        }
    }

    private func startDemo() {
        product = Demo.headphones
        checkingLabel = nil
        withAnimation(Motion.rise) { phase = .analyzing }
        withAnimation(.easeInOut(duration: 3.4)) { progress = 1 }
        // The same run in the pop-up (Live Activity), seen once the user leaves the app.
        Task { await CheckActivity.play(verdict: product.verdict, reason: Self.islandReason(product.summary), over: 3.5) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            threadID = store.startThread(for: product)
            withAnimation(Motion.screenSwap) { phase = .reveal }
        }
    }

    // The island wants a few words: the summary without its hedge word or full stop,
    // "Likely ~$40 less by Cyber Monday." → "~$40 less by Cyber Monday".
    // Backend reasons run longer, so it keeps the first eight words.
    static func islandReason(_ summary: String) -> String {
        var reason = summary.trimmingCharacters(in: .whitespaces)
        let words = reason.split(separator: " ")
        if words.count > 8 { reason = words.prefix(8).joined(separator: " ") }
        for hedge in ["Likely ", "Usually "] where reason.hasPrefix(hedge) {
            reason = String(reason.dropFirst(hedge.count))
            reason = reason.prefix(1).uppercased() + reason.dropFirst()
        }
        if reason.hasSuffix(".") { reason.removeLast() }
        return reason
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
