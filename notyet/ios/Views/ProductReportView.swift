// Target membership: app only.
// Top to bottom: verdict panel, current and projected price, 12-month chart,
// need-by and tracking, agent summary, where to buy.
import SwiftUI

struct ProductReportView: View {
    let result: FullResult
    let scanKey: String?          // nil when opened from Discover

    @EnvironmentObject var router: Router
    @AppStorage("defaultNeedByDays") private var needByDays = 30
    @State private var tracked = false
    @State private var working = false
    @State private var revealed = false

    private struct NeedBy: Hashable { let label: String; let days: Int }
    private let needByChoices = [NeedBy(label: "1 week", days: 7), NeedBy(label: "2 weeks", days: 14),
                                 NeedBy(label: "1 month", days: 30), NeedBy(label: "3 months", days: 90)]

    private var style: VerdictStyle { VerdictStyle(result.verdict) }
    private var projected: Double? {
        result.projectedPrice ?? result.expectedPrice.map { ($0.low + $0.high) / 2 }
    }
    private var waitDate: Date? { Theme.day(result.waitUntil) }
    private var needByDate: Date { Calendar.current.date(byAdding: .day, value: needByDays, to: .now) ?? .now }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(result.product.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.slate)
                verdictPanel
                priceRows
                Hairline()
                chart
                Hairline()
                trackSection
                Hairline()
                summary
                storeSection
            }
            .padding(20)
        }
        // Screenshot runs pass -scrollBottom to capture the lower half of the report.
        .defaultScrollAnchor(ProcessInfo.processInfo.arguments.contains("-scrollBottom") ? .bottom : .top)
        .background(Theme.paper)
        .onAppear { revealed = true }
    }

    // MARK: Verdict

    private var verdictPanel: some View {
        HStack(spacing: 0) {
            Rectangle().fill(style.color).frame(width: 6)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Verdict").font(.headline).foregroundStyle(Theme.slate)
                    Text(style.word)
                        .font(Theme.display(46))
                        .foregroundStyle(style.color)
                        .scaleEffect(revealed ? 1 : 0.85, anchor: .leading)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: revealed)
                    Spacer(minLength: 0)
                    Image(systemName: "dollarsign")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(style.color)
                        .symbolEffect(.bounce, value: revealed)
                }
                Text(result.oneLiner).font(.headline).foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Theme.prussian)
    }

    private var priceRows: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Current").foregroundStyle(Theme.slate)
                Spacer()
                Text(Theme.money(result.currentPrice)).font(Theme.display(30)).monospacedDigit().foregroundStyle(Theme.ink)
            }
            if let projected {
                HStack(alignment: .firstTextBaseline) {
                    Text(waitDate.map { "Projected by \($0.formatted(.dateTime.month(.abbreviated).day()))" } ?? "Projected")
                        .foregroundStyle(Theme.slate)
                    Spacer()
                    Image(systemName: projected >= result.currentPrice ? "arrow.up.right" : "arrow.down.right")
                        .foregroundStyle(style.color)
                    Text(Theme.money(projected)).font(Theme.display(30)).monospacedDigit().foregroundStyle(Theme.ink)
                }
            }
        }
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last 12 months").font(.headline).foregroundStyle(Theme.ink)
            PriceChartView(history: result.history, current: result.currentPrice,
                           projected: projected, projectedDate: waitDate, accent: style.color)
        }
    }

    // MARK: Tracking

    private var trackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let scanKey {
                Text("Need it by").font(.headline).foregroundStyle(Theme.ink)
                HStack(spacing: 8) {
                    ForEach(needByChoices, id: \.self) { choice in
                        Chip(title: choice.label, selected: needByDays == choice.days) { needByDays = choice.days }
                    }
                }
                Button {
                    Task { await track(scanKey) }
                } label: {
                    Text(tracked ? "Tracking daily" : "Track until I need it")
                }
                .buttonStyle(SharpButtonStyle())
                .disabled(tracked || working)
                .contextMenu {
                    Button("Demo: remind me in 10 seconds") {
                        Reminders.demoReminder(scanKey: scanKey, productName: result.product.name, body: result.oneLiner)
                    }
                }
            } else {
                Button {
                    Task { await checkNow() }
                } label: {
                    Text("Check this for me")
                }
                .buttonStyle(SharpButtonStyle())
                .disabled(working)
            }
        }
    }

    private func track(_ key: String) async {
        working = true
        defer { working = false }
        let needByString = Theme.dayString(needByDate)
        try? await ScanAPI.saveToWishlist(key: key, needBy: needByString)
        // Remind on the predicted best day if it lands before the need-by date, otherwise on the need-by date.
        let remindOn = result.waitUntil.flatMap { $0 <= needByString ? $0 : nil } ?? needByString
        Reminders.scheduleBuyReminder(scanKey: key, productName: result.product.name,
                                      buyDate: remindOn, body: result.oneLiner)
        tracked = true
    }

    private func checkNow() async {
        working = true
        defer { working = false }
        if let quick = try? await ScanAPI.ask(result.product.name) {
            router.openKey = quick.scanKey
        }
    }

    // MARK: Summary and store

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(summaryLine).font(.body.weight(.medium)).foregroundStyle(Theme.ink)
            Text(result.tldr).foregroundStyle(Theme.slate)
        }
    }

    private var summaryLine: String {
        let sources = result.sourcesChecked ?? max(result.history.count, 1)
        let years = result.yearsOfData ?? 0
        let span: String
        if years < 1 {
            let months = max(1, Int((years * 12).rounded()))
            span = months == 1 ? "a month" : "\(months) months"
        } else if years < 1.5 {
            span = "a year"
        } else {
            span = "\(Int(years.rounded())) years"
        }
        return "Searched \(sources) sources and \(span) of price trends."
    }

    @ViewBuilder private var storeSection: some View {
        if let store = result.whereToBuy {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Buy at").foregroundStyle(Theme.slate)
                    Spacer()
                    Text(store.retailer).font(.headline).foregroundStyle(Theme.ink)
                    Text(Theme.money(store.totalCost)).monospacedDigit().foregroundStyle(Theme.ink)
                }
                if let rating = result.avgRating {
                    HStack(spacing: 6) {
                        Text("Avg review").foregroundStyle(Theme.slate)
                        Spacer()
                        StarsView(rating: rating)
                        Text(String(format: "%.1f", rating)).monospacedDigit().foregroundStyle(Theme.ink)
                    }
                }
                if let url = URL(string: store.url) {
                    Link(destination: url) { Text("Open on \(store.retailer)") }
                        .buttonStyle(SharpButtonStyle(filled: false))
                }
            }
        }
    }
}

#Preview {
    ProductReportView(result: SampleData.report, scanKey: "preview")
        .environmentObject(Router.shared)
        .preferredColorScheme(.dark)
}
