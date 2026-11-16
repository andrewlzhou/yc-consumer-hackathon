import Foundation

// Mirrors convex/lib/contract.ts on ruhaan_backend. Decoding is lenient so new backend fields never break the phone.
public enum Verdict: String, Codable, Sendable, CaseIterable {
    case buyNow = "BUY_NOW"
    case wait = "WAIT"
    case considerAlternative = "CONSIDER_ALTERNATIVE"
    case investigate = "INVESTIGATE"

    public var label: String {
        switch self {
        case .buyNow: "BUY NOW"
        case .wait: "WAIT"
        case .considerAlternative: "CONSIDER ALTERNATIVE"
        case .investigate: "INVESTIGATE"
        }
    }
}

// phone -> backend. Only extracted fields or a link; never image bytes.
public struct ProductExtract: Codable, Equatable, Sendable {
    public var deviceId: String
    public var retailer: String?
    public var title: String?
    public var currentPrice: Double?
    public var originalPrice: Double?
    public var url: String?
    public var ocrLines: [String]?
    public var capturedAt: Double?

    public init(deviceId: String, retailer: String? = nil, title: String? = nil, currentPrice: Double? = nil,
                originalPrice: Double? = nil, url: String? = nil, ocrLines: [String]? = nil, capturedAt: Double? = nil) {
        self.deviceId = deviceId
        self.retailer = retailer
        self.title = title
        self.currentPrice = currentPrice
        self.originalPrice = originalPrice
        self.url = url
        self.ocrLines = ocrLines
        self.capturedAt = capturedAt
    }
}

public struct AnalyzeResponse: Codable, Equatable, Sendable {
    public var productId: String?
    public var matchedTitle: String?
    public var verdict: Verdict
    public var reason: String
    public var confidence: Double
    public var isSampleData: Bool
    public var reportStatus: String?
}

public struct ReportResponse: Decodable, Sendable {
    public struct Product: Decodable, Sendable {
        public var productId: String
        public var title: String
        public var brand: String?
        public var isSample: Bool?
    }

    public struct Chart: Decodable, Sendable {
        public struct Point: Decodable, Sendable {
            public var date: String
            public var price: Double
            public var source: String
        }
        public struct Series: Decodable, Sendable {
            public var retailer: String
            public var points: [Point]
            public var lowest: Double
            public var latest: Double
        }
        public struct Low: Decodable, Sendable {
            public var price: Double
            public var date: String
            public var retailer: String
        }
        public struct Event: Decodable, Sendable {
            public var name: String
            public var startsAt: String
            public var endsAt: String
        }
        public var series: [Series]
        public var lowest: Low?
        public var events: [Event]?
        public var typicalPrice: Double?
        public var sources: [String: Double]?
        public var isSampleData: Bool
    }

    public struct Analysis: Decodable, Sendable {
        public var tier: String
        public var source: String?
        public var createdAt: Double?
        // The price the scan behind this analysis saw; nil when that scan had none.
        public var scanPrice: Double?
        public var verdict: Verdict
        public var confidence: Double
        public var reason: String
        public var isSampleData: Bool
        public var report: Report?
        public var insights: Insights?
    }

    public struct Report: Decodable, Sendable {
        public struct Summary: Decodable, Sendable { public var summary: String }
        public struct Discount: Decodable, Sendable {
            public var status: String
            public var explanation: String
        }
        public struct Forecast: Decodable, Sendable {
            public var low: Double?
            public var high: Double?
            public var byDate: String?
            public var confidence: Double
            public var explanation: String
        }
        public struct Competitor: Decodable, Sendable {
            public var productId: String
            public var title: String
            public var valueReasoning: String
        }
        public struct Recommendation: Decodable, Sendable { public var reasoning: String }
        public var priceAssessment: Summary?
        public var discount: Discount?
        public var forecast: Forecast?
        public var retailers: Summary?
        public var competitors: [Competitor]?
        public var recommendation: Recommendation?
    }

    public struct Insights: Decodable, Sendable {
        public struct Forecast: Decodable, Sendable {
            public var outlook: String
            public var low: Double?
            public var high: Double?
            public var byDate: String?
            public var eventName: String?
            public var confidence: Double
        }
        public struct DiscountAuthenticity: Decodable, Sendable {
            public var claimedWasPrice: Double?
            public var wasPriceChargedSharePercent: Double?
            public var claimedDiscountPercent: Double?
            public var realDiscountVsTypicalPercent: Double?
            public var discountingIsRoutine: Bool
        }
        public struct Competitor: Decodable, Sendable {
            public var productId: String
            public var title: String
            public var brand: String?
            public var latestPrice: Double
            public var retailer: String?
            public var similarityPercent: Double?
            public var savingsVsCurrent: Double?
            public var savingsPercent: Double?
        }
        public var forecast: Forecast?
        public var discountAuthenticity: DiscountAuthenticity?
        public var competitorComparison: [Competitor]?
    }

    public var product: Product
    public var pending: Bool
    public var chart: Chart?
    public var analysis: Analysis?
}

public struct WatchPrefs: Codable, Equatable, Sendable {
    public var target_hit = true
    public var new_low = true
    public var buy_now_flip = true
    public var sale_start = true
    public var better_alternative = true
    public init() {}
}

public struct WatchItem: Decodable, Identifiable, Sendable {
    public var id: String { productId }
    public var productId: String
    public var targetPrice: Double?
    public var prefs: WatchPrefs?
    public var lastPrice: Double?
    public var lastVerdict: Verdict?
    public var lastReason: String?
    public var lastCheckedAt: Double?
    public var createdAt: Double?
}

public struct InboxNotification: Decodable, Identifiable, Sendable {
    public var id: String
    public var productId: String
    public var title: String
    public var body: String
    public var price: Double
    public var verdict: Verdict
    public var trigger: String
    public var simulated: Bool
    public var createdAt: Double
}
