// Target membership: app only. Mock data so the UI person can build every screen in Xcode
// Previews before the backend is ready. Same shape the backend returns.
import Foundation

enum SampleData {
    static let report: FullResult = try! JSONDecoder().decode(FullResult.self, from: Data(json.utf8))

    // One of each verdict so every screen state can be checked.
    static let buyNow = make(name: "Kindle Paperwhite", verdict: "BUY_NOW", oneLiner: "Buy now. Lowest price this year.",
                             current: 129, projected: 159, waitUntil: nil, retailer: "Amazon",
                             tldr: "It has only been this low twice. It goes back to $159 after sales.")
    static let fakeDeal = make(name: "Dyson V15 Detect", verdict: "FAKE_DEAL", oneLiner: "Fake deal. It was $549 in May.",
                               current: 649, projected: 599, waitUntil: "2026-11-27", retailer: "Best Buy",
                               tldr: "The crossed-out price was never real. Expect about $599 on Black Friday.")

    /// Mock lookups by scan key: "b" is a fake deal, "c" is buy now, anything else is wait.
    static func result(for key: String) -> FullResult {
        switch key {
        case "b": return fakeDeal
        case "c": return buyNow
        default: return report
        }
    }

    static let discover: [DiscoverItem] = [
        DiscoverItem(key: "c", discount: 19, result: buyNow),
        DiscoverItem(key: "a", discount: 12, result: report),
    ]

    private static func make(name: String, verdict: String, oneLiner: String, current: Double, projected: Double,
                             waitUntil: String?, retailer: String, tldr: String) -> FullResult {
        let wait = waitUntil.map { "\"\($0)\"" } ?? "null"
        let shape: [(String, Double)] = [("2025-12-01", 0.82), ("2026-01-20", 1.0), ("2026-03-15", 0.95),
                                         ("2026-05-10", 1.0), ("2026-07-09", 0.88), ("2026-09-05", 1.0), ("2026-11-10", 1.0)]
        let history = shape.map { "{\"date\":\"\($0.0)\",\"price\":\(Int(current * $0.1)),\"retailer\":\"\(retailer)\",\"source\":\"wayback\"}" }
            .joined(separator: ",")
        let json = """
        {"product":{"name":"\(name)","brand":null,"model":null},"verdict":"\(verdict)","oneLiner":"\(oneLiner)",
         "confidence":0.74,"currentPrice":\(current),"expectedPrice":null,"waitUntil":\(wait),
         "whereToBuy":{"retailer":"\(retailer)","price":\(current),"totalCost":\(current),"url":"https://example.com","reason":null},
         "history":[\(history)],"tldr":"\(tldr)","projectedPrice":\(projected),"sourcesChecked":18,"yearsOfData":1.6,
         "avgRating":4.4,"reviewCount":3120}
        """
        return try! JSONDecoder().decode(FullResult.self, from: Data(json.utf8))
    }

    static let history: [HistoryItem] = [
        HistoryItem(scanKey: "a", status: "done", createdAt: Date().timeIntervalSince1970 * 1000,
                    productName: "JBL Tour One M2 Headphones", verdict: "WAIT", oneLiner: "Wait. Likely ~$45 less on Cyber Monday.",
                    retailer: "Amazon", currentPrice: 249, saved: true, needBy: "2026-12-20", lastPrice: 249, dropped: false),
        HistoryItem(scanKey: "b", status: "done", createdAt: (Date().timeIntervalSince1970 - 7200) * 1000,
                    productName: "Dyson V15 Detect", verdict: "FAKE_DEAL", oneLiner: "Fake deal. It was $549 in May.",
                    retailer: "Best Buy", currentPrice: 649, saved: false, needBy: nil, lastPrice: nil, dropped: nil),
        HistoryItem(scanKey: "c", status: "done", createdAt: (Date().timeIntervalSince1970 - 400000) * 1000,
                    productName: "Kindle Paperwhite", verdict: "BUY_NOW", oneLiner: "Buy now. Lowest price this year.",
                    retailer: "Amazon", currentPrice: 129, saved: false, needBy: nil, lastPrice: nil, dropped: nil),
    ]

    static let wishlist: [WishlistItem] = [
        WishlistItem(scanKey: "a", productName: "AirPods Pro 3", buyDate: "2026-11-30", targetPrice: 205),
        WishlistItem(scanKey: "d", productName: "Nintendo Switch 2", buyDate: "2026-11-27", targetPrice: 429),
    ]

    // Placeholder numbers for design only. Real numbers come from your scans.
    private static let json = """
    {
      "product": { "name": "AirPods Pro 3", "brand": "Apple", "model": "MFHP4" },
      "verdict": "WAIT",
      "oneLiner": "Wait. Likely ~$45 less on Cyber Monday.",
      "confidence": 0.78,
      "currentPrice": 249,
      "expectedPrice": { "low": 199, "high": 205 },
      "waitUntil": "2026-11-30",
      "whereToBuy": { "retailer": "Best Buy", "price": 249, "totalCost": 249,
                      "url": "https://www.bestbuy.com", "reason": "Sold by the retailer, not a marketplace seller, and arrives before your date." },
      "history": [
        { "date": "2025-12-01", "price": 199, "retailer": "Amazon", "source": "deal_post" },
        { "date": "2026-01-15", "price": 249, "retailer": "Best Buy", "source": "wayback" },
        { "date": "2026-03-10", "price": 239, "retailer": "Amazon", "source": "wayback" },
        { "date": "2026-05-20", "price": 249, "retailer": "Best Buy", "source": "wayback" },
        { "date": "2026-07-09", "price": 219, "retailer": "Amazon", "source": "deal_post" },
        { "date": "2026-09-01", "price": 249, "retailer": "Best Buy", "source": "wayback" },
        { "date": "2026-11-10", "price": 249, "retailer": "Best Buy", "source": "wayback" }
      ],
      "tldr": "It dropped about 20% last Black Friday and Cyber Monday. Wait until Nov 30, then buy at Best Buy.",
      "projectedPrice": 202,
      "sourcesChecked": 23,
      "yearsOfData": 1.9,
      "avgRating": 4.6,
      "reviewCount": 12480
    }
    """
}
