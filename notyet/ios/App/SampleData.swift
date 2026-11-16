// Target membership: app only. Mock data so the UI person can build every screen in Xcode
// Previews before the backend is ready. Same shape the backend returns.
import Foundation

enum SampleData {
    static let report: FullResult = try! JSONDecoder().decode(FullResult.self, from: Data(json.utf8))

    // One of each verdict so every screen state can be checked. All of it is sample data, and says so.
    static let buyNow = make(name: "Kindle Paperwhite", verdict: "BUY_NOW", oneLiner: "Buy now. Lowest price this year.",
                             current: 129, projected: 159, waitUntil: nil, retailer: "Amazon", confidence: 0.86,
                             tldr: "It has only been this low twice. It goes back to $159 after sales.",
                             extra: """
                             "typicalPrice":159,
                             "lowest":{"price":129,"date":"2026-11-10","retailer":"Amazon"},
                             "forecast":{"low":129,"high":159,"byDate":null,"outlook":"no_better_price_expected","eventName":null,
                                         "confidence":0.8,"savingsAtLow":0,"savingsAtLowPercent":0},
                             "discount":{"status":"genuine","claimedWasPrice":159,"claimedDiscountPercent":19,"realDiscountPercent":19,
                                         "wasPriceChargedSharePercent":84},
                             "keyFacts":["$30 under its usual $159.","Only the second time at $129 in a year.","Sales on it end within a week."]
                             """)
    static let fakeDeal = make(name: "Dyson V15 Detect", verdict: "FAKE_DEAL", oneLiner: "Fake deal. It was $549 in May.",
                               current: 649, projected: 599, waitUntil: "2026-11-27", retailer: "Best Buy",
                               tldr: "The crossed-out price was never real. Expect about $599 on Black Friday.",
                               extra: """
                               "typicalPrice":599,
                               "lowest":{"price":549,"date":"2026-05-10","retailer":"Best Buy"},
                               "forecast":{"low":579,"high":599,"byDate":"2026-11-27","outlook":"better_price_likely","eventName":"Black Friday",
                                           "confidence":0.7,"savingsAtLow":70,"savingsAtLowPercent":11},
                               "discount":{"status":"misleading","explanation":"The $799 was-price was charged on 4% of days.",
                                           "claimedWasPrice":799,"claimedDiscountPercent":19,"realDiscountPercent":-8,"wasPriceChargedSharePercent":4},
                               "keyFacts":["Raised to $799 two weeks before the sale.","$50 above its usual $599.","Was $549 in May."],
                               "saleEvents":[{"name":"Black Friday","startsAt":"2025-11-28","endsAt":"2025-12-02"},
                                             {"name":"Memorial Day","startsAt":"2026-05-22","endsAt":"2026-05-26"}]
                               """)
    static let considerAlternative = make(
        name: "Sony WH-1000XM6", verdict: "CONSIDER_ALTERNATIVE",
        oneLiner: "The XM5 does nearly the same for $150 less.",
        current: 449, projected: 429, waitUntil: nil, retailer: "Amazon", confidence: 0.68,
        tldr: "The XM6 rarely goes on sale yet. The XM5 shares most of its specs and is at its low.",
        extra: """
        "typicalPrice":449,
        "lowest":{"price":429,"date":"2026-07-09","retailer":"Amazon"},
        "forecast":{"low":399,"high":429,"byDate":"2026-11-27","outlook":"better_price_possible","eventName":"Black Friday",
                    "confidence":0.5,"savingsAtLow":50,"savingsAtLowPercent":11},
        "discount":{"status":"no_discount_claimed"},
        "keyFacts":["Sold at $449 on 10 of the last 12 months.","Two similar headphones cost far less right now."],
        "alternatives":[
          {"title":"Sony WH-1000XM5","brand":"Sony","price":298,"retailer":"Best Buy","savingsVsCurrent":151,"savingsPercent":34,
           "similarityPercent":88,"reasoning":"Same noise cancelling and battery; older case and mics.","url":"https://www.bestbuy.com"},
          {"title":"Bose QuietComfort Ultra","brand":"Bose","price":349,"retailer":"Amazon","savingsVsCurrent":100,"savingsPercent":22,
           "similarityPercent":74,"reasoning":"Comparable cancelling, shorter battery.","url":"https://www.amazon.com"}
        ]
        """)
    static let investigate = make(
        name: "Apple Watch Ultra 2", verdict: "INVESTIGATE",
        oneLiner: "Far below every store. Check the seller first.",
        current: 489, projected: 749, waitUntil: nil, retailer: "Marketplace seller", confidence: 0.41,
        tldr: "No major store has sold it under $699. Prices this low usually mean refurbished, grey-market or a listing error.",
        extra: """
        "matchNote":"Matched by title only. The model number wasn't on the page.","typicalPrice":799,
        "lowest":{"price":699,"date":"2025-11-28","retailer":"Amazon"},
        "forecast":{"low":699,"high":749,"byDate":"2026-11-27","outlook":"unknown","eventName":"Black Friday","confidence":0.35},
        "discount":{"status":"unclear","claimedWasPrice":799,"claimedDiscountPercent":39},
        "keyFacts":["$310 under its usual $799.","The lowest store price was $699, last Black Friday.","Seller has no rating history."]
        """)

    /// Mock lookups by scan key: "b" is a fake deal, "c" is buy now, "d" is consider an alternative,
    /// "e" is investigate, anything else is wait.
    static func result(for key: String) -> FullResult {
        switch key {
        case "b": return fakeDeal
        case "c": return buyNow
        case "d": return considerAlternative
        case "e": return investigate
        default: return report
        }
    }

    static let discover: [DiscoverItem] = [
        DiscoverItem(key: "c", discount: 19, result: buyNow),
        DiscoverItem(key: "a", discount: 12, result: report),
    ]

    // `extra` is more JSON fields (no leading or trailing comma) for that verdict.
    private static func make(name: String, verdict: String, oneLiner: String, current: Double, projected: Double,
                             waitUntil: String?, retailer: String, confidence: Double = 0.74,
                             tldr: String, extra: String) -> FullResult {
        let wait = waitUntil.map { "\"\($0)\"" } ?? "null"
        let shape: [(String, Double)] = [("2025-12-01", 0.82), ("2026-01-20", 1.0), ("2026-03-15", 0.95),
                                         ("2026-05-10", 1.0), ("2026-07-09", 0.88), ("2026-09-05", 1.0), ("2026-11-10", 1.0)]
        let history = shape.map { "{\"date\":\"\($0.0)\",\"price\":\(Int(current * $0.1)),\"retailer\":\"\(retailer)\",\"source\":\"wayback\"}" }
            .joined(separator: ",")
        let json = """
        {"product":{"name":"\(name)","brand":null,"model":null},"verdict":"\(verdict)","oneLiner":"\(oneLiner)",
         "confidence":\(confidence),"currentPrice":\(current),"expectedPrice":null,"waitUntil":\(wait),
         "whereToBuy":{"retailer":"\(retailer)","price":\(current),"totalCost":\(current),"url":"https://example.com","reason":null},
         "history":[\(history)],"tldr":"\(tldr)","projectedPrice":\(projected),"sourcesChecked":18,"yearsOfData":1.6,
         "avgRating":4.4,"reviewCount":3120,"isSampleData":true,\(extra)}
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
      "reviewCount": 12480,
      "isSampleData": true,
      "typicalPrice": 249,
      "lowest": { "price": 199, "date": "2025-12-01", "retailer": "Amazon" },
      "forecast": { "low": 199, "high": 205, "byDate": "2026-11-30", "outlook": "better_price_likely",
                    "eventName": "Cyber Monday", "confidence": 0.72, "savingsAtLow": 50, "savingsAtLowPercent": 20 },
      "discount": { "status": "no_discount_claimed" },
      "keyFacts": ["Dropped to $199 last Black Friday.", "Sold at $249 on 9 of the last 12 months.",
                   "Best Buy and Amazon match each other within a day."],
      "saleEvents": [ { "name": "Black Friday", "startsAt": "2025-11-28", "endsAt": "2025-12-02" },
                      { "name": "Prime Day", "startsAt": "2026-07-08", "endsAt": "2026-07-11" } ]
    }
    """
}
