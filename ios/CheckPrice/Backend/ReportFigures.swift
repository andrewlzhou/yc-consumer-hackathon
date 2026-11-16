// Turns GET /report into the numbers the thread's report and chart draw (`ThreadDetailFigures`), and adds to a
// checked product what its report knows. The report is about the product, not about this check: it carries the
// newest analysis from any scan on any phone. So the check's own price, store, verdict and reason stay, the chart
// is the product's history, and the analysis (verdict, reason, forecast) is used only when it was made for the
// same price this check saw.
import Foundation
import ShopperKit

extension ThreadDetailFigures {
    // The numbers a thread's report draws. Demo products get demo history; a checked product only ever gets its
    // own report's numbers, and nothing until that report has a chart.
    static func forThread(product: Product, report: ReportResponse?, today: Date = .now) -> ThreadDetailFigures? {
        guard let check = product.check else { return ThreadDetailDemoHistory.figures(for: product, today: today) }
        guard let report, report.product.productId == product.productId else { return nil }
        return ThreadDetailFigures(report: report, product: product, check: check)
    }

    // nil until the report carries a chart with at least one price, or when the product has no price for today
    // (a link whose store has no fresh price): the chart is drawn around today's price.
    init?(report: ReportResponse, product: Product, check: CheckSnapshot) {
        guard let chart = report.chart, let current = ThreadDetailDemoHistory.dollars(in: product.price).first else { return nil }
        let points = chart.series.flatMap { series in
            series.points.map { PricePoint(date: $0.date, price: $0.price, retailer: series.retailer) }
        }.sorted { $0.date < $1.date }
        guard !points.isEmpty else { return nil }

        let analysis = report.analysis(for: check)
        let range = Self.forecastRange(analysis)
        let cheapest = points.min { $0.price < $1.price }
        let low = chart.lowest?.price ?? cheapest?.price ?? current
        let lowDate = ChartFormat.day(chart.lowest?.date ?? cheapest?.date) ?? .now

        self.init(
            current: current,
            predictedLow: range ?? current...current,
            predictedDate: Self.forecastDate(analysis).flatMap { ChartFormat.day($0) },
            typical: chart.typicalPrice ?? current,
            low: low,
            lowDate: lowDate,
            history: points,
            sales: (chart.events ?? []).map { SaleWindow(name: $0.name, startsAt: $0.startsAt, endsAt: $0.endsAt) },
            sources: Self.sources(chart),
            hasForecast: range != nil,
            isSampleData: chart.isSampleData
        )
    }

    // The report's price sources, most prices first ("serpapi", "12 prices").
    static func sources(_ chart: ReportResponse.Chart) -> [ProductSource] {
        (chart.sources ?? [:])
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { ProductSource(name: $0.key, detail: $0.value == 1 ? "1 price" : "\(Int($0.value)) prices") }
    }

    // The code-computed forecast first (deterministic), then the model's.
    static func forecastRange(_ analysis: ReportResponse.Analysis?) -> ClosedRange<Double>? {
        let insight = analysis?.insights?.forecast
        let model = analysis?.report?.forecast
        guard let low = insight?.low ?? model?.low else { return nil }
        let high = max(low, insight?.high ?? model?.high ?? low)
        return low...high
    }

    static func forecastDate(_ analysis: ReportResponse.Analysis?) -> String? {
        analysis?.insights?.forecast?.byDate ?? analysis?.report?.forecast?.byDate
    }
}

extension ReportResponse {
    // The report's analysis, when it speaks for this check: made for the same price, or both without one.
    // Another scan's analysis of the same product is not this check's verdict.
    func analysis(for check: CheckSnapshot) -> Analysis? {
        guard let analysis else { return nil }
        switch (check.price, analysis.scanPrice) {
        case let (mine?, theirs?): return abs(mine - theirs) < 0.005 ? analysis : nil
        case (nil, nil): return analysis
        default: return nil
        }
    }
}

// One store's newest price in a report's chart, kept with the store and day it belongs to.
struct StoreOffer: Equatable {
    let retailer: String
    let price: Double
    let day: Date
}

extension ReportResponse.Chart {
    // A price counts as today's for a week after it was last seen.
    static let freshDays = 7.0

    // The newest price at the checked store, if seen in the last week. Another store's price is never shown under
    // this store's name; when the check named no store, the lowest fresh price comes with its own store.
    func freshOffer(at retailer: String, now: Date = .now) -> StoreOffer? {
        let offers = series.compactMap { series -> StoreOffer? in
            guard let last = series.points.last, let day = ChartFormat.day(last.date),
                  now.timeIntervalSince(day) < Self.freshDays * 86_400 else { return nil }
            return StoreOffer(retailer: series.retailer, price: series.latest, day: day)
        }
        if retailer.isEmpty { return offers.min { $0.price < $1.price } }
        return offers.first { StoreName.same($0.retailer, retailer) }
    }
}

enum StoreName {
    // "Best Buy", "Bestbuy", "bestbuy.com" and the backend's "bestbuy" are one store.
    static func key(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: ".com", with: "").filter { $0.isLetter || $0.isNumber }
    }

    static func same(_ a: String, _ b: String) -> Bool { !key(a).isEmpty && key(a) == key(b) }
}

extension Product {
    // The checked product with what its report adds. Always rebuilt from the check itself, so repeated or late
    // reports can't drift: a link gets today's price from its own store, and a matching analysis gives the
    // forecast and, once the full analysis is in, the refined verdict and reason.
    func updated(with report: ReportResponse) -> Product {
        guard let check, report.product.productId == productId else { return self }
        var product = self
        product.retailer = check.retailer
        product.price = check.price.map(Money.text) ?? ""
        product.verdict = check.verdict
        product.summary = check.reason
        product.isSampleData = check.isSampleData
        product.projectedLow = ""
        product.reasoning = ""
        if check.price == nil, let offer = report.chart?.freshOffer(at: check.retailer) {
            product.price = Money.text(offer.price)
            if check.retailer.isEmpty { product.retailer = offer.retailer }
        }
        guard let analysis = report.analysis(for: check) else { return product }
        if let range = ThreadDetailFigures.forecastRange(analysis) {
            product.projectedLow = range.lowerBound == range.upperBound
                ? Money.text(range.lowerBound)
                : "\(Money.text(range.lowerBound))–\(Money.text(range.upperBound))"
        }
        if !report.pending {
            product.verdict = Verdict(analysis.verdict)
            product.summary = analysis.reason
            product.reasoning = analysis.report?.recommendation?.reasoning ?? ""
            product.isSampleData = analysis.isSampleData
        }
        return product
    }
}
