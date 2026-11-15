import Charts
import ShopperKit
import SwiftUI

// GET /report on demand: chart, forecast, discount check, competitors and the reasoning.
struct ReportView: View {
    @EnvironmentObject var model: AppModel
    let productId: String
    @State private var report: ReportResponse?
    @State private var error: String?

    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red) }
            if let report {
                Section {
                    Text(report.product.title).font(.headline)
                    if report.pending { Text("Full analysis still running; pull to refresh in a few seconds.").font(.caption) }
                    if let a = report.analysis {
                        VerdictBadge(verdict: a.verdict)
                        Text(a.reason)
                        Text("Confidence \(Int((a.confidence * 100).rounded()))% · \(a.tier) analysis").font(.caption)
                    }
                    if report.chart?.isSampleData == true || report.analysis?.isSampleData == true {
                        Text("Includes sample data, not real prices.").font(.caption).foregroundStyle(.orange)
                    }
                }
                if let chart = report.chart, !chart.series.isEmpty { chartSection(chart) }
                if let a = report.analysis { analysisSections(a) }
            } else if error == nil {
                ProgressView()
            }
        }
        .navigationTitle("Report")
        .refreshable { await load() }
        .task {
            await load()
            if report?.pending == true {
                try? await Task.sleep(for: .seconds(10))
                await load()
            }
        }
    }

    private func chartSection(_ chart: ReportResponse.Chart) -> some View {
        Section("Price history") {
            Chart {
                ForEach(chart.series, id: \.retailer) { series in
                    ForEach(series.points, id: \.date) { point in
                        LineMark(x: .value("Date", Self.date(point.date)), y: .value("Price", point.price))
                            .interpolationMethod(.stepEnd)
                            .foregroundStyle(by: .value("Store", series.retailer))
                    }
                }
                if let typical = chart.typicalPrice {
                    RuleMark(y: .value("Typical", typical)).lineStyle(StrokeStyle(dash: [4])).foregroundStyle(.gray)
                }
            }
            .frame(height: 200)
            if let low = chart.lowest { Text("Lowest: \(Self.money(low.price)) at \(low.retailer) on \(low.date)").font(.caption) }
            if let typical = chart.typicalPrice { Text("Typical: \(Self.money(typical))").font(.caption) }
        }
    }

    @ViewBuilder
    private func analysisSections(_ a: ReportResponse.Analysis) -> some View {
        if let f = a.insights?.forecast, f.outlook != "unknown" {
            Section("Forecast") {
                Text(f.outlook.replacingOccurrences(of: "_", with: " ").capitalized)
                if let low = f.low, let high = f.high {
                    Text("Expected \(Self.money(low))-\(Self.money(high))\(f.byDate.map { " by " + $0 } ?? "")\(f.eventName.map { " (" + $0 + ")" } ?? "")")
                }
                Text("Confidence \(Int((f.confidence * 100).rounded()))%").font(.caption)
            }
        } else if let f = a.report?.forecast {
            Section("Forecast") {
                Text(f.explanation)
                Text("Confidence \(Int((f.confidence * 100).rounded()))%").font(.caption)
            }
        }
        if let d = a.report?.discount {
            Section("Is the discount real?") {
                Text(d.status.replacingOccurrences(of: "_", with: " ").capitalized).font(.subheadline)
                Text(d.explanation)
                if let real = a.insights?.discountAuthenticity?.realDiscountVsTypicalPercent {
                    Text("Real saving vs typical price: \(Int(real.rounded()))%").font(.caption)
                }
            }
        }
        if let competitors = a.insights?.competitorComparison, !competitors.isEmpty {
            Section("Alternatives") {
                ForEach(competitors, id: \.productId) { c in
                    VStack(alignment: .leading) {
                        Text(c.title).font(.subheadline)
                        Text("\(Self.money(c.latestPrice))\(c.retailer.map { " at " + $0 } ?? "")\(c.savingsPercent.map { String(format: " · %.0f%% cheaper", $0) } ?? "")").font(.caption)
                    }
                }
            }
        }
        if let summary = a.report?.priceAssessment?.summary { Section("Price") { Text(summary) } }
        if let reasoning = a.report?.recommendation?.reasoning { Section("Why") { Text(reasoning) } }
    }

    private func load() async {
        do {
            report = try await model.client.report(productId: productId)
            error = nil
        } catch let e as ShopperError {
            error = e.message
        } catch {
            self.error = ShopperError.network.message
        }
    }

    static func date(_ text: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: String(text.prefix(10))) ?? .distantPast
    }

    static func money(_ value: Double) -> String { String(format: "$%.2f", value) }
}
