// Below Home's first screen: totals across all threads, then the three newest. Everything is
// computed from `ThreadStore.threads`, so it changes as checks are made or saved.
import SwiftUI

struct HomeSummary: View {
    @Environment(ThreadStore.self) private var store

    var body: some View {
        let threads = store.threads
        VStack(alignment: .leading, spacing: 28) {
            section("Summary") {
                FlatCard {
                    VStack(spacing: 0) {
                        SummaryRow(title: "Checks this month", value: "\(HomeTotals.checksThisMonth(threads))")
                        Hairline()
                        SummaryRow(title: "Watching", value: "\(store.saved.count)")
                        Hairline()
                        SummaryRow(title: "Saved by waiting", value: HomeTotals.savedByWaiting(store.saved))
                    }
                }
                Text("Estimated: today’s price minus the predicted low.")
                    .textStyle(.footnote)
                    .foregroundStyle(Palette.textTertiary)
            }
            section("Verdicts") { VerdictBreakdown(threads: threads) }
            if !threads.isEmpty {
                section("Recent") {
                    ForEach(HomeTotals.newest(threads, count: 3)) { thread in
                        SignalRow(product: thread.product, note: thread.startedAt.formatted(.relative(presentation: .named))) {
                            store.openThreadID = thread.id
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.top, 32)
        .padding(.bottom, 40)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title)
            content()
        }
    }
}

// How many threads ended in each verdict: a bar split by colour, then one row per verdict.
private struct VerdictBreakdown: View {
    let threads: [ShoppingThread]
    private let verdicts: [Verdict] = [.buyNow, .wait, .alternative, .investigate]

    var body: some View {
        FlatCard {
            VStack(spacing: 0) {
                bar.padding(Spacing.cardLeading)
                ForEach(verdicts, id: \.self) { verdict in
                    Hairline()
                    SummaryRow(title: verdict.word, value: "\(count(verdict))") {
                        Image(systemName: verdict.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(verdict.color)
                            .frame(width: 22)
                    }
                }
            }
        }
    }

    private var bar: some View {
        GeometryReader { proxy in
            let total = max(threads.count, 1)
            HStack(spacing: 2) {
                ForEach(verdicts.filter { count($0) > 0 }, id: \.self) { verdict in
                    Capsule()
                        .fill(verdict.color)
                        .frame(width: max(0, proxy.size.width * Double(count(verdict)) / Double(total) - 2))
                }
            }
        }
        .frame(height: 6)
        .background { Capsule().fill(.white.opacity(0.06)) }
        .accessibilityHidden(true)
    }

    private func count(_ verdict: Verdict) -> Int {
        threads.filter { $0.product.verdict == verdict }.count
    }
}

// One line of a summary card: an optional leading symbol, a name, and a number on the right.
private struct SummaryRow<Leading: View>: View {
    let title: String
    let value: String
    let leading: Leading

    init(title: String, value: String, @ViewBuilder leading: () -> Leading) {
        self.title = title
        self.value = value
        self.leading = leading()
    }

    var body: some View {
        HStack(spacing: Spacing.rowIconToText) {
            leading
            Text(title)
                .textStyle(.item)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            Text(value)
                .textStyle(.item)
                .monospacedDigit()
                .foregroundStyle(Palette.textSecondary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, Spacing.cardLeading)
        .frame(height: 48)
        .accessibilityElement(children: .combine)
    }
}

extension SummaryRow where Leading == EmptyView {
    init(title: String, value: String) {
        self.init(title: title, value: value) { EmptyView() }
    }
}

// The arithmetic behind the summary.
enum HomeTotals {
    static func checksThisMonth(_ threads: [ShoppingThread], now: Date = .now) -> Int {
        threads.filter { Calendar.current.isDate($0.startedAt, equalTo: now, toGranularity: .month) }.count
    }

    static func newest(_ threads: [ShoppingThread], count: Int) -> [ShoppingThread] {
        Array(threads.sorted { $0.startedAt > $1.startedAt }.prefix(count))
    }

    // Today's price minus the low end of the predicted range, summed over saved threads, as "$70".
    static func savedByWaiting(_ saved: [ShoppingThread]) -> String {
        let total = saved.reduce(0.0) { sum, thread in
            guard let price = dollars(thread.product.price), let low = dollars(thread.product.projectedLow) else { return sum }
            return sum + max(0, price - low)
        }
        return total.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    // The first dollar amount in a string: "$309–$319" → 309, "$1,299" → 1299.
    static func dollars(_ text: String) -> Double? {
        let number = text
            .drop { !$0.isNumber }
            .prefix { $0.isNumber || $0 == "," || $0 == "." }
            .filter { $0 != "," }
        return Double(String(number))
    }
}
