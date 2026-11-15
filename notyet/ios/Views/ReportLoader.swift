// Target membership: app only.
// Loads a scan by key. While the check runs it shows four steps (find the product, check prices,
// read the price history, pick the verdict) with the current one moving, and the quick verdict as
// soon as the server has it. If the server stops answering, the check fails, or it runs past five
// minutes, it says so and offers to look again.
import SwiftUI

struct ReportLoader: View {
    let key: String
    @State private var scan: ScanResponse?
    @State private var stalled: Stall?
    // Bumped by "Try again" to restart polling.
    @State private var attempt = 0

    // The phone gave up waiting; the server may still be working.
    enum Stall { case unreachable, timedOut }

    // No successful answer for this long: the scan is unreachable (offline, or the upload never landed).
    private static let unreachableAfter: TimeInterval = 45
    // Total time before we stop polling and say it is taking too long.
    private static let giveUpAfter: TimeInterval = 300
    private static let pollEvery: Duration = .seconds(2)

    var body: some View {
        ZStack {
            if let result = scan?.result {
                ProductReportView(result: result, scanKey: key)
                    .transition(.opacity)
            } else if let problem {
                ScanProblemView(problem: problem, retry: problem.canRetry ? { retry() } : nil)
                    .transition(.opacity)
            } else {
                DiggingView(status: scan?.status, step: scan?.step, quick: scan?.quick)
                    .transition(.opacity)
            }
        }
        .animation(Motion.screenSwap, value: phase)
        .background(Palette.canvas)
        .task(id: "\(key)#\(attempt)") { await poll() }
    }

    // What failed, if anything. Server answers win over the phone's own timeouts.
    private var problem: ScanProblem? {
        if scan?.status == "error" {
            return scan?.error == "No product found" ? .notFound : .failed
        }
        if scan?.status == "done" && scan?.result == nil { return .failed }
        switch stalled {
        case .unreachable: return .unreachable
        case .timedOut: return .timedOut
        case nil: return nil
        }
    }

    // Which of the three screens is up, so the swap between them animates once.
    private var phase: Int {
        if scan?.result != nil { return 2 }
        return problem == nil ? 0 : 1
    }

    private func retry() {
        stalled = nil
        attempt += 1
    }

    private func poll() async {
        let start = Date()
        var lastAnswer = start
        while !Task.isCancelled {
            do {
                let s = try await ScanAPI.fetchScan(key: key)
                lastAnswer = Date()
                withAnimation(Motion.layout) { scan = s }
                if s.status == "done" || s.status == "error" { return }
            } catch {
                if Task.isCancelled { return }
                if Date().timeIntervalSince(lastAnswer) > Self.unreachableAfter {
                    stalled = .unreachable
                    return
                }
            }
            if Date().timeIntervalSince(start) > Self.giveUpAfter {
                stalled = .timedOut
                return
            }
            try? await Task.sleep(for: Self.pollEvery)
        }
    }
}

// MARK: - Waiting

// The four steps a check goes through, in order.
enum DigStage: Int, CaseIterable {
    case finding, prices, history, verdict

    var label: String {
        switch self {
        case .finding: "Finding the product"
        case .prices: "Checking prices"
        case .history: "Reading price history"
        case .verdict: "Picking the verdict"
        }
    }

    // The server reports progress as a status ("working", "deep") and a step sentence. Known
    // sentences map to a step; anything else falls back on the status, so new wording never
    // moves progress backwards past what the status already says.
    init(status: String?, step: String?) {
        let floor: DigStage = status == "deep" ? .history : .finding
        let text = (step ?? "").lowercased()
        let fromText: DigStage? =
            if text.contains("picking") || text.contains("verdict") || text.contains("best time") { .verdict }
            else if text.contains("history") || text.contains("trend") { .history }
            else if text.contains("price") { .prices }
            else if text.contains("finding") || text.contains("product") || text.contains("start") { .finding }
            else { nil }
        self = max(floor, fromText ?? floor)
    }
}

extension DigStage: Comparable {
    static func < (a: DigStage, b: DigStage) -> Bool { a.rawValue < b.rawValue }
}

struct DiggingView: View {
    let status: String?
    let step: String?
    let quick: QuickInfo?

    init(status: String? = nil, step: String?, quick: QuickInfo?) {
        self.status = status
        self.step = step
        self.quick = quick
    }

    private var stage: DigStage { DigStage(status: status, step: step) }

    var body: some View {
        ZStack {
            BackdropGradient()
                .opacity(0.55)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.titleToForm) {
                    header
                    StageList(current: stage)
                        .padding(.horizontal, Spacing.cardLeading)
                        .padding(.vertical, Spacing.cardTop)
                        .glassSurface()
                    if let quick, quick.verdict != nil || quick.oneLiner != nil {
                        QuickAnswer(quick: quick)
                            .transition(.rise)
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.top, 40)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(Motion.rise, value: quick?.oneLiner)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Digging")
                    .textStyle(.title)
                    .foregroundStyle(Palette.textPrimary)
                HoppingDots(color: Palette.textPrimary)
            }
            if let name = quick?.productName {
                Text(name)
                    .textStyle(.body)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(2)
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// One row per step: done steps get a check, the current one a spinner and a shimmer, later
// ones stay dim.
private struct StageList: View {
    let current: DigStage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(DigStage.allCases, id: \.self) { stage in
                row(stage)
            }
        }
        .animation(Motion.layout, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current.rawValue + 1) of \(DigStage.allCases.count): \(current.label)")
    }

    private func row(_ stage: DigStage) -> some View {
        let isDone = stage < current
        let isNow = stage == current
        return HStack(spacing: Spacing.rowIconToText) {
            ZStack {
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                } else if isNow {
                    WorkingIndicator(size: 15, color: Palette.glow)
                        .transition(.opacity)
                } else {
                    Circle()
                        .strokeBorder(Palette.textTertiary, lineWidth: 1)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(width: 18, height: 18)

            Text(stage.label)
                .textStyle(.item)
                .foregroundStyle(isNow ? Palette.textPrimary : isDone ? Palette.textSecondary : Palette.textTertiary)
                .shimmering(isNow)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
    }
}

// The quick verdict, shown while the full report is still being written.
private struct QuickAnswer: View {
    let quick: QuickInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("First look")
                .textStyle(.section)
                .foregroundStyle(Palette.textTertiary)
            if let verdict = quick.verdict {
                let style = VerdictStyle(verdict)
                Text(style.word)
                    .textStyle(.statement(size: 30))
                    .foregroundStyle(style.color)
            }
            if let line = quick.oneLiner {
                Text(line)
                    .textStyle(.body)
                    .lineSpacing(4)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                WorkingIndicator(size: 12, color: Palette.textTertiary)
                Text("Full report on its way")
                    .textStyle(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, Spacing.cardLeading)
        .padding(.vertical, Spacing.cardBottom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { FlatCard { Color.clear } }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Problems

enum ScanProblem {
    case notFound, failed, unreachable, timedOut

    var symbol: String {
        switch self {
        case .notFound: "magnifyingglass"
        case .failed: "exclamationmark.triangle"
        case .unreachable: "wifi.exclamationmark"
        case .timedOut: "hourglass"
        }
    }

    var title: String {
        switch self {
        case .notFound: "No product found"
        case .failed: "Couldn't finish this check"
        case .unreachable: "Couldn't load this check"
        case .timedOut: "Taking longer than usual"
        }
    }

    var detail: String {
        switch self {
        case .notFound, .failed: "Try the product page or the exact model name."
        case .unreachable: "Check your connection, then try again."
        case .timedOut: "It may still finish. Look again in a minute."
        }
    }

    // Looking again only helps when the phone gave up, not when the server gave an answer.
    var canRetry: Bool { self == .unreachable || self == .timedOut }
}

// Worldscape's empty/failed state: one light symbol, one line, one hint, one small key.
struct ScanProblemView: View {
    let problem: ScanProblem
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: problem.symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Palette.danger)
                .padding(.bottom, 4)
            Text(problem.title)
                .textStyle(.cardTitle)
                .foregroundStyle(Palette.textPrimary)
            Text(problem.detail)
                .textStyle(.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            if let retry {
                Button("Try again", action: retry)
                    .buttonStyle(KeyButtonStyle(tone: .secondary))
                    .padding(.top, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Digging") {
    DiggingView(status: "deep", step: "Reading the price history…",
                quick: QuickInfo(productName: "Sony WH-1000XM5", verdict: "WAIT",
                                 oneLiner: "Usually drops to $298 around Black Friday."))
        .background(Palette.canvas)
        .preferredColorScheme(.dark)
}

#Preview("Problem") {
    ScanProblemView(problem: .unreachable, retry: {})
        .background(Palette.canvas)
        .preferredColorScheme(.dark)
}
