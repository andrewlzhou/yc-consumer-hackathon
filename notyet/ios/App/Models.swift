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
