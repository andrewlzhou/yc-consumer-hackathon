// Turns GET /report into the numbers the thread's report and chart draw (`ThreadDetailFigures`),
// and fills a real product's price and predicted low once the report knows them.
import Foundation
import ShopperKit

extension ThreadDetailFigures {
    // nil until the report carries a chart with at least one price.
    init?(report: ReportResponse, product: Product) {
        guard let chart = report.chart, !chart.series.isEmpty else { return nil }
        let points = chart.series.flatMap { series in
            series.points.map { PricePoint(date: $0.date, price: $0.price, retailer: series.retailer) }
        }.sorted { $0.date < $1.date }
        guard !points.isEmpty else { return nil }

        let current = ThreadDetailDemoHistory.dollars(in: product.price).first ?? Self.latest(chart, retailer: product.retailer)
        let range = Self.forecastRange(report)
        let low = chart.lowest?.price ?? points.map(\.price).min() ?? current
        let lowDate = chart.lowest.flatMap { ChartFormat.day($0.date) } ?? .now

        self.init(
            current: current,
            predictedLow: range ?? current...current,
            predictedDate: Self.forecastDate(report).flatMap { ChartFormat.day($0) },
            typical: chart.typicalPrice ?? current,
            low: low,
            lowDate: lowDate,
            history: points,
            sales: (chart.events ?? []).map { SaleWindow(name: $0.name, startsAt: $0.startsAt, endsAt: $0.endsAt) },
            hasForecast: range != nil,
            isSampleData: chart.isSampleData
        )
    }

    // The newest price at this retailer, or the lowest newest price across retailers.
    static func latest(_ chart: ReportResponse.Chart, retailer: String) -> Double {
        let match = chart.series.first { $0.retailer.localizedCaseInsensitiveContains(retailer) && !retailer.isEmpty }
        return match?.latest ?? chart.series.map(\.latest).min() ?? 0
    }

    // The code-computed forecast first (deterministic), then the model's.
    static func forecastRange(_ report: ReportResponse) -> ClosedRange<Double>? {
        let insight = report.analysis?.insights?.forecast
        let model = report.analysis?.report?.forecast
        guard let low = insight?.low ?? model?.low else { return nil }
        let high = max(low, insight?.high ?? model?.high ?? low)
        return low...high
    }

    static func forecastDate(_ report: ReportResponse) -> String? {
        report.analysis?.insights?.forecast?.byDate ?? report.analysis?.report?.forecast?.byDate
    }
}

extension Product {
    // Fills blanks from the report: today's price from the chart, the predicted low from the forecast,
    // and the backend's latest verdict and reason once the full analysis is in.
    func updated(with report: ReportResponse) -> Product {
        var product = self
        if product.price.isEmpty, let chart = report.chart, !chart.series.isEmpty {
            product.price = Money.text(ThreadDetailFigures.latest(chart, retailer: retailer))
        }
        if let range = ThreadDetailFigures.forecastRange(report) {
            product.projectedLow = range.lowerBound == range.upperBound
                ? Money.text(range.lowerBound)
                : "\(Money.text(range.lowerBound))–\(Money.text(range.upperBound))"
        }
        if let analysis = report.analysis, !report.pending {
            product.verdict = Verdict(analysis.verdict)
            product.summary = analysis.reason
            product.isSampleData = analysis.isSampleData
        }
        return product
    }
}
