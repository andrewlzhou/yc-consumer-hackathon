// Target membership: app only.
// 12 months of price history, a dashed "Today" line, and a dashed projection into the future.
import SwiftUI
import Charts

private struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let price: Double
}

struct PriceChartView: View {
    let history: [FullResult.Point]
    let current: Double
    let projected: Double?
    let projectedDate: Date?
    var accent: Color = Theme.prussianLight

    private let today = Date()

    private var past: [ChartPoint] {
        let start = Calendar.current.date(byAdding: .month, value: -12, to: today) ?? today
        var points = history.map { ChartPoint(date: $0.day, price: $0.price) }
        points = points.filter { $0.date >= start && $0.date <= today }
        points.sort { $0.date < $1.date }
        points.append(ChartPoint(date: today, price: current))
        return points
    }

    private var futureDate: Date {
        if let d = projectedDate, d > today { return d }
        return Calendar.current.date(byAdding: .day, value: 30, to: today) ?? today
    }

    private var yDomain: ClosedRange<Double> {
        let prices = past.map(\.price) + [projected ?? current]
        let low = (prices.min() ?? current) * 0.95
        let high = max((prices.max() ?? current) * 1.05, low + 1)
        return low...high
    }

    var body: some View {
        Chart {
            ForEach(past) { p in
                LineMark(x: .value("Date", p.date), y: .value("Price", p.price), series: .value("Series", "History"))
                    .interpolationMethod(.linear)
                    .foregroundStyle(Theme.ink)
            }
            if let projected {
                LineMark(x: .value("Date", today), y: .value("Price", current), series: .value("Series", "Projected"))
                    .foregroundStyle(accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                LineMark(x: .value("Date", futureDate), y: .value("Price", projected), series: .value("Series", "Projected"))
                    .foregroundStyle(accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                PointMark(x: .value("Date", futureDate), y: .value("Price", projected))
                    .symbol(.square)
                    .foregroundStyle(accent)
            }
            RuleMark(x: .value("Today", today))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(Theme.slate)
                .annotation(position: .top, alignment: .center) {
                    Text("Today").font(.caption2).foregroundStyle(Theme.slate)
                }
            PointMark(x: .value("Date", today), y: .value("Price", current))
                .symbol(.square)
                .foregroundStyle(Theme.ink)
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel(format: .dateTime.month(.abbreviated)).foregroundStyle(Theme.slate)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel {
                    if let v = value.as(Double.self) { Text("$\(Int(v))").foregroundStyle(Theme.slate) }
                }
            }
        }
        .frame(height: 220)
        .accessibilityLabel("Price over the last 12 months, now \(Theme.money(current))")
    }
}
