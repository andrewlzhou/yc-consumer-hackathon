// The check behind Home's round button: a store link on the clipboard goes to the backend
// (Backend/Backend.swift); otherwise the user picks a screenshot, read on the phone. While it runs,
// `phase` drives Home's check sheet (`CheckSheet`): analyzing, then the verdict reveal. A failure
// closes the sheet and leaves `failure` for Home to show. Builds without a backend key, and
// `-autoReveal YES`, run the demo on `Demo.headphones`.
import PhotosUI
import ShopperKit
import SwiftUI

@MainActor @Observable
final class CheckFlow {
    enum Phase { case analyzing, reveal }

    // nil when no check is on screen; Home shows the sheet whenever it is set.
    var phase: Phase?
    // How far the analyzing line should be, and how it gets there. The line animates itself, since
    // the sheet appears a moment after the check starts.
    var progress = 0.0
    var progressAnimation = Animation.default
    var product = Demo.headphones
    // While analyzing a link: its store's domain, since the product isn't known yet.
    var checkingLabel: String?
    var pickingScreenshot = false
    var failure: String?
    private(set) var threadID: UUID?

    // A store link on the clipboard is checked right away; otherwise the user picks a screenshot.
    func start(store: ThreadStore) {
        failure = nil
        guard !(Backend.config.apiKey ?? "").isEmpty else { return startDemo(store: store) }
        if UIPasteboard.general.hasURLs, let url = UIPasteboard.general.url, url.scheme?.hasPrefix("http") == true {
            checkingLabel = url.host()?.replacingOccurrences(of: "www.", with: "")
            run(store: store) { await CheckRunner.run(url: url) }
        } else {
            pickingScreenshot = true
        }
    }

    func checkScreenshot(_ item: PhotosPickerItem, store: ThreadStore) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            failure = ShopperError.unreadableImage.message
            return
        }
        checkingLabel = nil
        run(store: store) { await CheckRunner.run(imageData: data) }
    }

    // Analyzing while the backend answers (the line fills to 90%, then completes), then the reveal and a
    // new thread, or the sheet closes with the failure. The pop-up checks alongside and shows the verdict.
    // If the user closed the sheet meanwhile, the thread is still made but the sheet stays closed.
    private func run(store: ThreadStore, _ check: @escaping () async -> Result<CheckResult, ShopperError>) {
        product = Product(name: "", retailer: "", price: "", icon: "tag", verdict: .investigate, summary: "", projectedLow: "")
        setProgress(0.9, .easeOut(duration: 6))
        phase = .analyzing
        Task { @MainActor in
            let activity = await CheckActivity.start()
            switch await check() {
            case let .success(result):
                product = result.product
                if let activity {
                    await CheckActivity.decide(activity, verdict: product.verdict, reason: Self.islandReason(product.summary), phase: 1)
                }
                setProgress(1, .easeOut(duration: 0.3))
                try? await Task.sleep(for: .seconds(0.3))
                let id = store.startThread(for: product)
                threadID = id
                store.loadReport(for: id)
                if phase != nil { withAnimation(Motion.screenSwap) { phase = .reveal } }
            case let .failure(error):
                if let activity { await activity.end(nil, dismissalPolicy: .immediate) }
                failure = error.message
                phase = nil
            }
        }
    }

    func startDemo(store: ThreadStore) {
        product = Demo.headphones
        checkingLabel = nil
        setProgress(1, .easeInOut(duration: 3.4))
        phase = .analyzing
        // The same run in the pop-up (Live Activity), seen once the user leaves the app.
        Task { await CheckActivity.play(verdict: product.verdict, reason: Self.islandReason(product.summary), over: 3.5) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            threadID = store.startThread(for: product)
            if phase != nil { withAnimation(Motion.screenSwap) { phase = .reveal } }
        }
    }

    private func setProgress(_ value: Double, _ animation: Animation) {
        progressAnimation = animation
        progress = value
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
}

// The check's sheet: the analyzing card, then the reveal (verdict word, summary, today and the
// predicted low, Details). Same pieces as the old Home check, now over the app backdrop in a sheet.
struct CheckSheet: View {
    let flow: CheckFlow
    let openDetails: () -> Void
    // Flips once the reveal is on screen, so its parts can rise in one after another.
    @State private var arrived = false

    var body: some View {
        ZStack(alignment: .leading) {
            switch flow.phase {
            case .analyzing: analyzing.transition(.rise)
            case .reveal: reveal
            case nil: EmptyView()
            }
        }
        .padding(.horizontal, Spacing.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var analyzing: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: Spacing.rowIconToText) {
                Image(systemName: flow.checkingLabel == nil ? flow.product.icon : "tag")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: ControlHeight.avatar, height: ControlHeight.avatar)
                    .background { Circle().fill(.white.opacity(0.1)) }
                Text(flow.checkingLabel ?? flow.product.name)
                    .textStyle(.cardTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(2)
            }
            ProgressLine(value: flow.progress, animation: flow.progressAnimation)
        }
        .padding(.horizontal, Spacing.cardLeading)
        .padding(.top, Spacing.cardTop + 4)
        .padding(.bottom, Spacing.cardBottom + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { flatCard }
    }

    // The verdict arrives in steps: word, summary, then the numbers, each rising in with a spring.
    private var reveal: some View {
        let product = flow.product
        return VStack(alignment: .leading, spacing: 0) {
            Text(product.verdict.word)
                .textStyle(.wordmark(size: 72))
                .foregroundStyle(product.verdict.color)
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
                .padding(.horizontal, Spacing.cardLeading)
                .padding(.vertical, 16)
                .background { flatCard }
                Button("Details", action: openDetails)
                    .buttonStyle(KeyButtonStyle())
            }
            .padding(.top, Spacing.titleToForm)
            .modifier(RiseEffect(progress: arrived ? 1 : 0))
            .animation(Motion.cardArrive.delay(0.3), value: arrived)
        }
        .onAppear { arrived = true }
    }

    private var flatCard: some View {
        FlatCard(cornerRadius: Radius.glassCard) { Color.clear }
    }
}

// A thin white line that fills as the check runs, easing to each new value from where it is.
private struct ProgressLine: View {
    let value: Double
    let animation: Animation
    @State private var drawn = 0.0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule().fill(.white.opacity(0.9)).frame(width: proxy.size.width * drawn)
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
        .onAppear { withAnimation(animation) { drawn = value } }
        .onChange(of: value) { _, new in withAnimation(animation) { drawn = new } }
    }
}
