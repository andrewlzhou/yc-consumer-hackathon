// The numbers behind a thread's report: today's price and the predicted low read from the demo
// `Product` strings, plus a demo year of price history for the chart, built from the product's own
// numbers and seeded by its name, so a thread shows the same chart every time it opens. Replace `ThreadDetailDemoHistory` when a backend sends real history.
import Foundation

struct ThreadDetailFigures {
    let current: Double
    // The predicted low as a range ("$309–$319" -> 309...319); one number gives a zero-width range.
    let predictedLow: ClosedRange<Double>
    // When the predicted low is expected, if the product says.
    let predictedDate: Date?
    // What it usually sells for, and the lowest price of the past year.
    let typical: Double
    let low: Double
    let lowDate: Date
    // Chart inputs.
    let history: [PricePoint]
    let sales: [SaleWindow]

    var predictedMid: Double { (predictedLow.lowerBound + predictedLow.upperBound) / 2 }
    var lowest: PriceLow { PriceLow(price: low, date: ThreadDetailDemoHistory.dayString(lowDate)) }
}

enum ThreadDetailDemoHistory {
    static func figures(for product: Product, today: Date = .now) -> ThreadDetailFigures {
        let current = dollars(in: product.price).first ?? 0
        let range = dollars(in: product.projectedLow)
        let predictedLow = (range.min() ?? current)...(range.max() ?? current)
        var rng = SeededRandom(seed: product.name)

        // The usual price and the year's low, shaped so the chart backs the verdict.
        let typical: Double
        let low: Double
        switch product.verdict {
        case .buyNow:
            typical = (current * 1.12).rounded()
            low = max(1, current - 10)
        case .wait:
            typical = current
            low = max(1, predictedLow.lowerBound - 10)
        case .alternative, .investigate:
            typical = (current * 1.04).rounded()
            low = max(1, min(predictedLow.lowerBound, (current * 0.88).rounded()))
        }

        // Past sales in the last year, each with the price it reached. Black Friday reaches the low.
        let start = calendar.date(byAdding: .day, value: -365, to: today) ?? today
        var windows: [(name: String, start: Date, end: Date, price: Double)] = []
        for event in pastEvents(before: today) where event.start >= start {
            let price: Double
            switch event.name {
            case "Black Friday": price = low
            case "Prime Day": price = (low + (typical - low) * 0.35).rounded()
            default: price = (typical - (typical - low) * 0.55).rounded()
            }
            windows.append((event.name, event.start, event.end, price))
        }

        // Regular price: a step every two to four weeks, a few percent either side of usual, kept
        // above the low and clear of the sale windows.
        var steps: [(date: Date, price: Double)] = []
        var day = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -400, to: today) ?? today) ?? today
        while day < today {
            // The day after a sale is taken: the price returns to usual then.
            let inSale = windows.contains { $0.start <= day && day.timeIntervalSince($0.end) <= 86_400 }
            if !inSale {
                let price = (typical * (1 + rng.next(in: -0.035...0.035))).rounded()
                steps.append((day, max(price, low + 5)))
            }
            day = calendar.date(byAdding: .day, value: Int(rng.next(in: 14...28)), to: day) ?? today
        }
        for window in windows {
            steps.append((window.start, window.price))
            let after = calendar.date(byAdding: .day, value: 1, to: window.end) ?? window.end
            if after < today { steps.append((after, typical)) }
        }
        steps.sort { $0.date < $1.date }

        let blackFriday = windows.first { $0.name == "Black Friday" }
        let lowDate = blackFriday?.start ?? (steps.first { $0.price == low }?.date ?? today)

        return ThreadDetailFigures(
            current: current,
            predictedLow: predictedLow,
            predictedDate: predictedDate(for: product, today: today),
            typical: typical,
            low: low,
            lowDate: lowDate,
            history: steps.map { PricePoint(date: dayString($0.date), price: $0.price, retailer: product.retailer) },
            sales: windows.map { SaleWindow(name: $0.name, startsAt: dayString($0.start), endsAt: dayString($0.end)) }
        )
    }

    // Every dollar amount in a string: "$309–$319" -> [309, 319].
    static func dollars(in text: String) -> [Double] {
        text.split { !($0.isNumber || $0 == ".") }.compactMap { Double($0) }
    }

    static func dayString(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // MARK: Dates

    // Noon UTC days, matching how the chart reads "YYYY-MM-DD".
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .now
    }

    // US Thanksgiving: the fourth Thursday of November.
    private static func thanksgiving(_ year: Int) -> Date {
        let first = date(year, 11, 1)
        let weekday = calendar.component(.weekday, from: first) // Sunday = 1, Thursday = 5
        let firstThursday = 1 + (5 - weekday + 7) % 7
        return date(year, 11, firstThursday + 21)
    }

    // The yearly sales, each in its most recent run that has already ended.
    private static func pastEvents(before today: Date) -> [(name: String, start: Date, end: Date)] {
        let year = calendar.component(.year, from: today)
        func latest(_ name: String, length: Int, start: (Int) -> Date) -> (name: String, start: Date, end: Date) {
            for y in [year, year - 1] {
                let s = start(y)
                let e = calendar.date(byAdding: .day, value: length, to: s) ?? s
                if e < today { return (name, s, e) }
            }
            let s = start(year - 2)
            return (name, s, calendar.date(byAdding: .day, value: length, to: s) ?? s)
        }
        return [
            latest("Presidents' Day", length: 4) { date($0, 2, 13) },
            latest("Prime Day", length: 3) { date($0, 7, 8) },
            latest("Labor Day", length: 5) { date($0, 8, 29) },
            // Black Friday through Cyber Monday.
            latest("Black Friday", length: 4) { calendar.date(byAdding: .day, value: 1, to: thanksgiving($0)) ?? date($0, 11, 28) },
        ]
    }

    // When the predicted low is due, read from the product's summary: Cyber Monday, after the
    // holidays, or nil when the summary names no time.
    private static func predictedDate(for product: Product, today: Date) -> Date? {
        let year = calendar.component(.year, from: today)
        let summary = product.summary.lowercased()
        if summary.contains("cyber monday") {
            let thisYear = calendar.date(byAdding: .day, value: 4, to: thanksgiving(year)) ?? today
            return thisYear > today ? thisYear : calendar.date(byAdding: .day, value: 4, to: thanksgiving(year + 1))
        }
        if summary.contains("holidays") {
            let thisYear = date(year, 1, 5)
            return thisYear > today ? thisYear : date(year + 1, 1, 5)
        }
        return nil
    }
}

// SplitMix64 seeded from the product name (FNV-1a), since `String.hashValue` changes every launch.
private struct SeededRandom {
    private var state: UInt64

    init(seed: String) {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        state = hash
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) / Double(1 << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}
