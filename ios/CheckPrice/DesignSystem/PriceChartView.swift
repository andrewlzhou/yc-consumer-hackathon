// Adapted from notyet/ios/Views/PriceChartView.swift (Not Yet). Changes: its own input types
// (`PricePoint`, `PriceLow`, `SaleWindow`, below) replace Not Yet's report models, the
// `init(result:)` convenience is gone, and the money/day helpers live here in `ChartFormat`.
// The report's price history. It makes the verdict's case: today's price against the typical price
// and the 12-month low, plus a dashed projection when there is one. Drag across the chart to read the
// price on any day. Worldscape look: dark, white line, one accent colour, springy arrival.
//
// Data: dated prices, drawn as a smooth line (monotone, so it never overshoots a real price) between
// points. Typical price and the low are computed from `history` when not given.
import SwiftUI
import Charts

struct PriceChartView: View {
    let history: [PricePoint]
    let current: Double
    let projected: Double?
    let projectedDate: Date?
    let accent: Color
    let typicalPrice: Double?
    let lowest: PriceLow?
    let saleEvents: [SaleWindow]
    let isSampleData: Bool

    init(history: [PricePoint], current: Double, projected: Double?, projectedDate: Date?,
         accent: Color = Palette.accent, typicalPrice: Double? = nil, lowest: PriceLow? = nil,
         saleEvents: [SaleWindow]? = nil, isSampleData: Bool = false) {
        self.history = history
        self.current = current
        self.projected = projected
        self.projectedDate = projectedDate
        self.accent = accent
        self.typicalPrice = typicalPrice
        self.lowest = lowest
        self.saleEvents = saleEvents ?? []
        self.isSampleData = isSampleData
    }

    @State private var selectedDate: Date?
    @State private var arrived = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // The 12-month low's marker. Accent (the verdict colour) is today; the low is neutral grey.
    private let lowColor = Palette.muted

    var body: some View {
        let plot = Plot.make(history: history, current: current, projected: projected,
                             projectedDate: projectedDate, typicalPrice: typicalPrice, lowest: lowest,
                             saleEvents: saleEvents)
        VStack(alignment: .leading, spacing: 14) {
            header(plot)
            chart(plot)
                .frame(height: 200)
            if isSampleData {
                Text("Sample data")
                    .textStyle(.footnote)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .onAppear {
            guard !arrived else { return }
            if reduceMotion {
                arrived = true
            } else {
                withAnimation(Motion.cardArrive.delay(0.1)) { arrived = true }
            }
        }
    }

    // MARK: Header: the key, or the day under the finger

    private func header(_ plot: Plot) -> some View {
        let reading = selectedDate.map { plot.reading(at: $0) }
        return ZStack(alignment: .topLeading) {
            HStack(alignment: .top, spacing: 12) {
                keyFigure("Today", value: current, glyph: dot(accent))
                if let typical = plot.typical {
                    keyFigure("Typical", value: typical, glyph: dash)
                }
                keyFigure("12-mo low", value: plot.low.price, glyph: dot(lowColor))
            }
            .opacity(reading == nil ? 1 : 0)

            if let reading {
                VStack(alignment: .leading, spacing: 4) {
                    Text(readingLabel(reading))
                        .textStyle(.footnote)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                    Text(ChartFormat.money(reading.point.price))
                        .font(.hiragino(.w6, size: 17, relativeTo: .headline))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textPrimary)
                        .contentTransition(.numericText())
                }
                .animation(Motion.valueChange, value: reading.point.id)
            }
        }
        .animation(Motion.hover, value: reading == nil)
        .accessibilityElement(children: .combine)
    }

    private func keyFigure(_ label: String, value: Double, glyph: some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                glyph
                Text(label)
                    .textStyle(.footnote)
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
            }
            Text(ChartFormat.money(value))
                .font(.hiragino(.w6, size: 17, relativeTo: .headline))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 7, height: 7)
    }

    // A short dashed line, matching the typical-price rule.
    private var dash: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 1))
            path.addLine(to: CGPoint(x: 12, y: 1))
        }
        .stroke(Palette.textTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
        .frame(width: 12, height: 2)
    }

    private func readingLabel(_ reading: Plot.Reading) -> String {
        var parts = [reading.isToday ? "Today" : reading.date.formatted(.dateTime.month(.abbreviated).day())]
        if !reading.isToday, let retailer = reading.point.retailer, !retailer.isEmpty { parts.append(retailer) }
        if let sale = reading.saleName { parts.append(sale) }
        return parts.joined(separator: " · ")
    }

    // MARK: Chart

    private func chart(_ plot: Plot) -> some View {
        // Before arrival every mark sits flat at the typical price; it then springs into shape.
        let base = plot.typical ?? current
        let reading = selectedDate.map { plot.reading(at: $0) }

        return Chart {
            // Past sale windows, shaded.
            ForEach(plot.sales) { sale in
                RectangleMark(xStart: .value("Sale start", sale.start), xEnd: .value("Sale end", sale.end))
                    .foregroundStyle(Color.white.opacity(0.05))
                    .opacity(arrived ? 1 : 0)
            }

            // Faint fill under the history.
            ForEach(plot.points) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Floor", plot.yDomain.lowerBound),
                    yEnd: .value("Price", arrived ? point.price : base)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(colors: [.white.opacity(0.10), .white.opacity(0)], startPoint: .top, endPoint: .bottom)
                )
            }

            // Typical price.
            if let typical = plot.typical {
                RuleMark(y: .value("Typical", typical))
                    .foregroundStyle(Palette.textTertiary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }

            // The price line.
            ForEach(plot.points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Price", arrived ? point.price : base),
                    series: .value("Series", "History")
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Palette.textPrimary)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }

            // Projection: dashed from today to the projected price.
            if let projection = plot.projection {
                LineMark(
                    x: .value("Date", plot.today),
                    y: .value("Price", arrived ? current : base),
                    series: .value("Series", "Projection")
                )
                .foregroundStyle(accent)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 4]))
                LineMark(
                    x: .value("Date", projection.date),
                    y: .value("Price", arrived ? projection.price : base),
                    series: .value("Series", "Projection")
                )
                .foregroundStyle(accent)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 4]))
                PointMark(x: .value("Date", projection.date), y: .value("Price", arrived ? projection.price : base))
                    .symbolSize(36)
                    .foregroundStyle(accent)
                    .opacity(arrived ? 1 : 0)
            }

            // The 12-month low, ringed in the canvas colour so it reads over the line. Skipped when
            // today is the low: today's marker already sits there.
            if plot.showsLowMarker {
                PointMark(x: .value("Date", plot.low.date), y: .value("Price", arrived ? plot.low.price : base))
                    .symbolSize(120)
                    .foregroundStyle(Palette.canvas)
                    .opacity(arrived ? 1 : 0)
                PointMark(x: .value("Date", plot.low.date), y: .value("Price", arrived ? plot.low.price : base))
                    .symbolSize(50)
                    .foregroundStyle(lowColor)
                    .opacity(arrived ? 1 : 0)
            }

            // Today, with a soft halo.
            PointMark(x: .value("Date", plot.today), y: .value("Price", arrived ? current : base))
                .symbolSize(280)
                .foregroundStyle(accent.opacity(0.22))
                .opacity(arrived ? 1 : 0)
            PointMark(x: .value("Date", plot.today), y: .value("Price", arrived ? current : base))
                .symbolSize(60)
                .foregroundStyle(accent)

            // The day under the finger.
            if let reading {
                RuleMark(x: .value("Selected", reading.date))
                    .foregroundStyle(Palette.strokeHover)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(x: .value("Selected", reading.date), y: .value("Price", reading.point.price))
                    .symbolSize(50)
                    .foregroundStyle(Palette.textPrimary)
            }
        }
        .chartXScale(domain: plot.start...plot.end)
        .chartYScale(domain: plot.yDomain)
        .chartLegend(.hidden)
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 3)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated))
                            .textStyle(.footnote)
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Palette.stroke)
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(ChartFormat.money(price))
                            .textStyle(.footnote)
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: reading?.point.id)
        .accessibilityLabel(accessibilitySummary(plot))
    }

    private func accessibilitySummary(_ plot: Plot) -> String {
        var parts = ["Price over the last 12 months.", "Today \(ChartFormat.money(current))."]
        if let typical = plot.typical { parts.append("Typical \(ChartFormat.money(typical)).") }
        parts.append("12-month low \(ChartFormat.money(plot.low.price)) on \(plot.low.date.formatted(.dateTime.month(.wide).day())).")
        if let projection = plot.projection {
            parts.append("Projected \(ChartFormat.money(projection.price)) by \(projection.date.formatted(.dateTime.month(.wide).day())).")
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Inputs

// One price in the history. `date` is "YYYY-MM-DD".
struct PricePoint: Identifiable {
    let date: String
    let price: Double
    var retailer: String? = nil
    var id: String { "\(date)-\(price)-\(retailer ?? "")" }
    var day: Date { ChartFormat.day(date) ?? .now }
}

// The lowest price seen, with when ("YYYY-MM-DD") and where.
struct PriceLow {
    var price: Double?
    var date: String?
    var retailer: String?
}

// A past sale window, shaded on the chart. Dates are "YYYY-MM-DD".
struct SaleWindow: Identifiable {
    var name: String?
    var startsAt: String?
    var endsAt: String?
    var id: String { "\(name ?? "")-\(startsAt ?? "")" }
}

enum ChartFormat {
    static func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    // "2026-11-30" -> Date
    static func day(_ s: String?) -> Date? {
        guard let s else { return nil }
        return ISO8601DateFormatter().date(from: s + "T12:00:00Z")
    }
}

// MARK: - The numbers behind the chart

// The 12-month low, with the day it was charged.
private struct Low {
    let price: Double
    let date: Date
}

private struct Sale: Identifiable {
    let id: Int
    let name: String?
    let start: Date
    let end: Date
}

private struct ChartPoint: Identifiable {
    let id: Int
    let date: Date
    let price: Double
    let retailer: String?
}

private struct Plot {
    struct Reading {
        let date: Date          // the finger's day, kept inside the history
        let point: ChartPoint   // the price in force that day
        let isToday: Bool
        let saleName: String?
    }

    let today: Date
    let start: Date
    let end: Date
    // Step series, oldest first; the last point is today at the current price.
    let points: [ChartPoint]
    let typical: Double?
    let low: Low
    let sales: [Sale]
    let projection: (date: Date, price: Double)?
    let yDomain: ClosedRange<Double>

    // The low has its own marker unless it is today's price or lies outside the window.
    var showsLowMarker: Bool {
        low.price < (points.last?.price ?? low.price)
            && low.date >= start && low.date <= today
    }

    static func make(history: [PricePoint], current: Double, projected: Double?, projectedDate: Date?,
                     typicalPrice: Double?, lowest: PriceLow?, saleEvents: [SaleWindow]) -> Plot {
        let today = Date()
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .month, value: -12, to: today) ?? today

        // Sort, drop anything after today, and carry the price in force at the window's start.
        let sorted = history
            .map { (date: $0.day, price: $0.price, retailer: $0.retailer) }
            .filter { $0.date <= today }
            .sorted { $0.date < $1.date }
        var raw = sorted.filter { $0.date >= start }
        if let before = sorted.last(where: { $0.date < start }) {
            raw.insert((date: start, price: before.price, retailer: before.retailer), at: 0)
        }
        raw.append((date: today, price: current, retailer: nil))
        let points = raw.enumerated().map { ChartPoint(id: $0.offset, date: $0.element.date, price: $0.element.price, retailer: $0.element.retailer) }

        let typical = typicalPrice ?? timeWeightedMedian(points, end: today)

        // Lowest price in the window, the most recent day it was charged. The backend's low wins
        // when it has both a price and a date.
        let computedLow: Low = {
            let minPrice = points.map(\.price).min() ?? current
            return Low(price: minPrice, date: points.last { $0.price == minPrice }?.date ?? today)
        }()
        var low = computedLow
        if let price = lowest?.price, let date = ChartFormat.day(lowest?.date) {
            low = Low(price: price, date: date)
        }

        // Sale windows that overlap the window, clipped to it.
        let sales: [Sale] = saleEvents.enumerated().compactMap { index, event in
            guard let from = ChartFormat.day(event.startsAt) else { return nil }
            let to = ChartFormat.day(event.endsAt) ?? from
            let clippedStart = max(from, start)
            let clippedEnd = min(max(to, from.addingTimeInterval(86_400)), today)
            guard clippedStart < clippedEnd else { return nil }
            return Sale(id: index, name: event.name, start: clippedStart, end: clippedEnd)
        }

        var projection: (date: Date, price: Double)?
        if let projected {
            let date = projectedDate.flatMap { $0 > today ? $0 : nil }
                ?? calendar.date(byAdding: .day, value: 30, to: today) ?? today
            projection = (date, projected)
        }

        // A little room right of the last mark so today's halo is not cut off.
        let lastDate = projection?.date ?? today
        let end = lastDate.addingTimeInterval(max(lastDate.timeIntervalSince(start) * 0.03, 86_400))

        let values = points.map(\.price) + [typical, low.price, projection?.price].compactMap { $0 }
        let lo = values.min() ?? current
        let hi = values.max() ?? current
        let span = max(hi - lo, hi * 0.04, 1)
        let yDomain = max(0, lo - span * 0.2)...(hi + span * 0.2)

        return Plot(today: today, start: start, end: end, points: points, typical: typical, low: low,
                    sales: sales, projection: projection, yDomain: yDomain)
    }

    // The price at a day, holding each price until the next change.
    func reading(at date: Date) -> Reading {
        let clamped = min(max(date, start), today)
        let fallback = points.last ?? ChartPoint(id: 0, date: today, price: low.price, retailer: nil)
        let point = points.last { $0.date <= clamped } ?? points.first ?? fallback
        let isToday = point.id == fallback.id || Calendar.current.isDate(clamped, inSameDayAs: today)
        let sale = sales.first { $0.start <= clamped && clamped <= $0.end }
        return Reading(date: clamped, point: isToday ? fallback : point, isToday: isToday, saleName: sale?.name)
    }

    // Median price weighted by how long each price held, so a one-day sale counts for one day.
    // Returns nil with fewer than two points: one price is not a typical price.
    private static func timeWeightedMedian(_ points: [ChartPoint], end: Date) -> Double? {
        guard points.count >= 2 else { return nil }
        var weighted: [(price: Double, weight: Double)] = []
        for (index, point) in points.enumerated() {
            let next = index + 1 < points.count ? points[index + 1].date : end
            weighted.append((point.price, max(0, next.timeIntervalSince(point.date))))
        }
        let total = weighted.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return nil }
        var running = 0.0
        for item in weighted.sorted(by: { $0.price < $1.price }) {
            running += item.weight
            if running >= total / 2 { return item.price }
        }
        return weighted.last?.price
    }
}
