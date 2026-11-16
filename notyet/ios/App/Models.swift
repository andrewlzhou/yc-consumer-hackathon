// Target membership: app only. Mirrors the JSON contract from Convex.
import Foundation

struct ScanResponse: Decodable {
    let status: String          // "working" | "deep" | "done" | "error"
    let step: String?
    let quick: QuickInfo?
    let result: FullResult?
    let error: String?
}

struct QuickInfo: Decodable {
    let productName: String?
    let verdict: String?
    let oneLiner: String?
    // Newer fields (backend contract `AnalyzeResponse`). Optional so older answers still decode.
    var confidence: Double? = nil          // 0...1
    var isSampleData: Bool? = nil          // the contract requires the phone to label sample data
    var verdictKind: Verdict { Verdict(verdict) }
}

struct FullResult: Decodable {
    struct Product: Decodable { let name: String; let brand: String?; let model: String? }
    struct PriceRange: Decodable { let low: Double; let high: Double }
    struct Store: Decodable { let retailer: String; let price: Double; let totalCost: Double; let url: String; let reason: String? }
    struct Point: Decodable, Identifiable {
        let date: String
        let price: Double
        let retailer: String?
        let source: String
        var id: String { "\(date)-\(price)-\(retailer ?? "")" }
        var day: Date { ISO8601DateFormatter().date(from: date + "T12:00:00Z") ?? .now }
    }

    let product: Product
    let verdict: String
    let oneLiner: String
    let confidence: Double
    let currentPrice: Double
    let expectedPrice: PriceRange?
    let waitUntil: String?
    let whereToBuy: Store?
    let history: [Point]
    let tldr: String

    // Newer fields. Optional so older saved results still decode.
    let projectedPrice: Double?
    let sourcesChecked: Int?
    let yearsOfData: Double?
    let avgRating: Double?
    let reviewCount: Int?

    // Fields from the new backend (`origin/ruhaan_backend:convex/lib/contract.ts`), flattened for the
    // phone. All optional and decoded tolerantly: a missing or malformed field becomes nil, it never
    // fails the whole report. The integrator maps `/report` onto these names.
    var isSampleData: Bool? = nil          // analysis.isSampleData or chart.isSampleData; must be labeled
    var matchNote: String? = nil           // report.match.note, e.g. "Matched by model number."
    var typicalPrice: Double? = nil        // chart.typicalPrice
    var lowest: LowPrice? = nil            // chart.lowest
    var forecast: Forecast? = nil          // insights.forecast (+ report.forecast.explanation)
    var discount: DiscountCheck? = nil     // report.discount + insights.discountAuthenticity
    var keyFacts: [String]? = nil          // short, already-written facts behind the verdict
    var alternatives: [Alternative]? = nil // insights.competitorComparison + report.competitors
    var saleEvents: [SaleEvent]? = nil     // chart.events
    var reportPending: Bool? = nil         // true while a fuller analysis is still running

    var verdictKind: Verdict { Verdict(verdict) }

    // The lowest price seen, with when and where.
    struct LowPrice: Decodable {
        var price: Double?
        var date: String?
        var retailer: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            price = try? c.decodeIfPresent(Double.self, forKey: .price)
            date = try? c.decodeIfPresent(String.self, forKey: .date)
            retailer = try? c.decodeIfPresent(String.self, forKey: .retailer)
        }
        private enum CodingKeys: String, CodingKey { case price, date, retailer }
    }

    // Where the price is likely heading.
    struct Forecast: Decodable {
        var low: Double?
        var high: Double?
        var byDate: String?                // "YYYY-MM-DD"
        // "better_price_likely" | "better_price_possible" | "no_better_price_expected" | "unknown"
        var outlook: String?
        var eventName: String?             // e.g. "Black Friday"
        var confidence: Double?            // 0...1
        var savingsAtLow: Double?          // dollars saved at `low` vs the current price
        var savingsAtLowPercent: Double?
        var explanation: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            low = try? c.decodeIfPresent(Double.self, forKey: .low)
            high = try? c.decodeIfPresent(Double.self, forKey: .high)
            byDate = try? c.decodeIfPresent(String.self, forKey: .byDate)
            outlook = try? c.decodeIfPresent(String.self, forKey: .outlook)
            eventName = try? c.decodeIfPresent(String.self, forKey: .eventName)
            confidence = try? c.decodeIfPresent(Double.self, forKey: .confidence)
            savingsAtLow = try? c.decodeIfPresent(Double.self, forKey: .savingsAtLow)
            savingsAtLowPercent = try? c.decodeIfPresent(Double.self, forKey: .savingsAtLowPercent)
            explanation = try? c.decodeIfPresent(String.self, forKey: .explanation)
        }
        private enum CodingKeys: String, CodingKey {
            case low, high, byDate, outlook, eventName, confidence, savingsAtLow, savingsAtLowPercent, explanation
        }
    }

    // Whether the advertised discount is real.
    struct DiscountCheck: Decodable {
        // "genuine" | "misleading" | "no_discount_claimed" | "unclear"
        var status: String?
        var explanation: String?
        var claimedWasPrice: Double?
        var claimedDiscountPercent: Double?
        var realDiscountPercent: Double?           // insights.realDiscountVsTypicalPercent
        var wasPriceChargedSharePercent: Double?   // how often the "was" price was actually charged

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            status = try? c.decodeIfPresent(String.self, forKey: .status)
            explanation = try? c.decodeIfPresent(String.self, forKey: .explanation)
            claimedWasPrice = try? c.decodeIfPresent(Double.self, forKey: .claimedWasPrice)
            claimedDiscountPercent = try? c.decodeIfPresent(Double.self, forKey: .claimedDiscountPercent)
            realDiscountPercent = try? c.decodeIfPresent(Double.self, forKey: .realDiscountPercent)
            wasPriceChargedSharePercent = try? c.decodeIfPresent(Double.self, forKey: .wasPriceChargedSharePercent)
        }
        private enum CodingKeys: String, CodingKey {
            case status, explanation, claimedWasPrice, claimedDiscountPercent, realDiscountPercent, wasPriceChargedSharePercent
        }
    }

    // A similar product worth comparing.
    struct Alternative: Decodable, Identifiable {
        var title: String?
        var brand: String?
        var price: Double?
        var retailer: String?
        var savingsVsCurrent: Double?      // dollars cheaper than this product
        var savingsPercent: Double?
        var similarityPercent: Double?
        var reasoning: String?
        var url: String?
        var id: String { "\(title ?? "")-\(retailer ?? "")-\(price ?? 0)" }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title = try? c.decodeIfPresent(String.self, forKey: .title)
            brand = try? c.decodeIfPresent(String.self, forKey: .brand)
            price = try? c.decodeIfPresent(Double.self, forKey: .price)
            retailer = try? c.decodeIfPresent(String.self, forKey: .retailer)
            savingsVsCurrent = try? c.decodeIfPresent(Double.self, forKey: .savingsVsCurrent)
            savingsPercent = try? c.decodeIfPresent(Double.self, forKey: .savingsPercent)
            similarityPercent = try? c.decodeIfPresent(Double.self, forKey: .similarityPercent)
            reasoning = try? c.decodeIfPresent(String.self, forKey: .reasoning)
            url = try? c.decodeIfPresent(String.self, forKey: .url)
        }
        private enum CodingKeys: String, CodingKey {
            case title, brand, price, retailer, savingsVsCurrent, savingsPercent, similarityPercent, reasoning, url
        }
    }

    // A past sale window, for shading the chart.
    struct SaleEvent: Decodable, Identifiable {
        var name: String?
        var startsAt: String?              // "YYYY-MM-DD"
        var endsAt: String?
        var id: String { "\(name ?? "")-\(startsAt ?? "")" }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try? c.decodeIfPresent(String.self, forKey: .name)
            startsAt = try? c.decodeIfPresent(String.self, forKey: .startsAt)
            endsAt = try? c.decodeIfPresent(String.self, forKey: .endsAt)
        }
        private enum CodingKeys: String, CodingKey { case name, startsAt, endsAt }
    }
}

// Every verdict the app knows. Old backend: BUY_NOW, WAIT, FAKE_DEAL. New backend adds
// CONSIDER_ALTERNATIVE and INVESTIGATE. Anything else (or nil) is `.unknown`, never a decode failure.
// Words and symbols are shared so every screen (and the widget's copy) says the same thing;
// colours live in `Views/DesignSystem/VerdictColors.swift` (`Verdict.color`).
enum Verdict: String, CaseIterable {
    case buyNow = "BUY_NOW"
    case wait = "WAIT"
    case fakeDeal = "FAKE_DEAL"
    case considerAlternative = "CONSIDER_ALTERNATIVE"
    case investigate = "INVESTIGATE"
    case unknown = "UNKNOWN"

    init(_ raw: String?) {
        self = raw.flatMap { Verdict(rawValue: $0.uppercased()) } ?? .unknown
    }

    // The big word on the report and the Live Activity.
    var word: String {
        switch self {
        case .buyNow: "Buy"
        case .wait: "Wait"
        case .fakeDeal: "Fake deal"
        case .considerAlternative: "Look around"
        case .investigate: "Check first"
        case .unknown: "Checking"
        }
    }

    // SF Symbol beside the word.
    var symbol: String {
        switch self {
        case .buyNow: "checkmark.circle.fill"
        case .wait: "clock.fill"
        case .fakeDeal: "exclamationmark.triangle.fill"
        case .considerAlternative: "arrow.left.arrow.right.circle.fill"
        case .investigate: "magnifyingglass.circle.fill"
        case .unknown: "ellipsis.circle.fill"
        }
    }

    // sRGB hex of the verdict colour, for targets that can't see `Palette` (the widget).
    var rgb: UInt32 {
        switch self {
        case .buyNow: 0x3DDC97              // green, kept from the original design
        case .wait: 0xFFB547                // amber, kept
        case .fakeDeal: 0xFF5C7A            // Worldscape danger red
        case .considerAlternative: 0xC4A7FF // lavender: readable on the blue backdrop, not a blue
        case .investigate: 0xFF9466         // coral: caution, short of the fake-deal red
        case .unknown: 0x9E9EA6             // grey
        }
    }
}

// History tab rows (GET /history)
struct HistoryItem: Decodable, Identifiable {
    let scanKey: String
    let status: String
    let createdAt: Double          // ms since 1970
    let productName: String?
    let verdict: String?
    let oneLiner: String?
    let retailer: String?
    let currentPrice: Double?
    let saved: Bool?
    let needBy: String?
    let lastPrice: Double?
    let dropped: Bool?
    var id: String { scanKey }
    var date: Date { Date(timeIntervalSince1970: createdAt / 1000) }
    var isTracking: Bool { saved ?? false }
    var verdictKind: Verdict { Verdict(verdict) }
}

// Wishlist tab rows (GET /wishlist)
struct WishlistItem: Decodable, Identifiable {
    let scanKey: String
    let productName: String
    let buyDate: String?
    let targetPrice: Double?
    var id: String { scanKey }
}

// Search tab "Discover" rows (GET /discover)
struct DiscoverItem: Decodable, Identifiable {
    let key: String
    let discount: Int        // percent below its typical price
    let result: FullResult
    var id: String { key }
}
