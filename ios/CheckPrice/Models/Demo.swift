// Four verdicts, a product, and the demo products the screens start with.
// Verdict words, symbols and colours live in DesignSystem/VerdictStyle.swift.
import SwiftUI

enum Verdict: String { case buyNow = "BUY NOW", wait = "WAIT", alternative = "CONSIDER ALTERNATIVE", investigate = "INVESTIGATE" }

// One place a report's numbers came from: a name and what it supplied ("Price history").
struct ProductSource: Hashable {
    let name: String
    let detail: String
}

// Demo products have no `productId`; checked ones carry the backend's catalog id (Backend/Backend.swift).
struct Product: Identifiable {
    let id = UUID()
    let name: String
    let retailer: String
    var price: String
    let icon: String
    var verdict: Verdict
    var summary: String
    var projectedLow: String
    var productId: String? = nil
    var isSampleData = false
    // Asset catalog name of the product's picture; nil shows a tile with `icon`.
    var image: String? = nil
    // The reason for the verdict, a short paragraph. The live version is meant to come from the
    // backend: Claude Opus 5.5 (`claude-opus-5-5`) writes it once per product and price-data
    // snapshot and the backend caches it, so reopening a thread shows the same text. For now checked
    // products take the report's recommendation reasoning; demo products carry text written by hand.
    var reasoning: String = ""
    // Where the demo numbers came from. Checked products list the report's sources instead.
    var sources: [ProductSource] = []
}

// Demo products: invented prices, reasons and sources (`isSampleData`), shown without a label so the
// demo reads like the real thing. The pictures are the manufacturers' own product images (Bose,
// Apple) and a drawn tile for the Vertuo, which could not be fetched.
enum Demo {
    static let headphones = Product(
        name: "QuietComfort Ultra Headphones", retailer: "Amazon", price: "$349", icon: "headphones", verdict: .wait,
        summary: "Likely ~$40 less by Cyber Monday.", projectedLow: "$309–$319", isSampleData: true,
        image: "product-quietcomfort-ultra",
        reasoning: "At $349, the QuietComfort Ultra is at its usual price on Amazon, not on sale. In the past year it reached $299 on Black Friday, and it fell about $40 in each of the last two November sales. We expect $309–$319 by Cyber Monday. Unless you need them this week, waiting should save you $30 to $40.",
        sources: [
            ProductSource(name: "Amazon", detail: "Listed price"),
            ProductSource(name: "Keepa", detail: "Price history"),
            ProductSource(name: "Best Buy", detail: "Comparison price"),
        ]
    )
    static let saved = [
        Product(
            name: "AirPods Pro (2nd gen)", retailer: "Best Buy", price: "$189", icon: "airpodspro", verdict: .buyNow,
            summary: "Within $10 of its lowest price.", projectedLow: "$179–$189", isSampleData: true,
            image: "product-airpods-pro",
            reasoning: "At $189, AirPods Pro are $23 below their usual $212 at Best Buy and within $10 of the year's low of $179, set on Black Friday. Prices this close to the low have lasted only a few days at a time. Waiting could save at most about $10, and that drop is not certain. Buying now is the better trade.",
            sources: [
                ProductSource(name: "Best Buy", detail: "Listed price"),
                ProductSource(name: "Amazon", detail: "Comparison price"),
                ProductSource(name: "CamelCamelCamel", detail: "Price history"),
            ]
        ),
        Product(
            name: "Nespresso Vertuo Pop+", retailer: "Target", price: "$129", icon: "cup.and.saucer.fill", verdict: .wait,
            summary: "Usually drops after the holidays.", projectedLow: "$99–$109", isSampleData: true,
            image: "product-vertuo-pop",
            reasoning: "At $129, the Vertuo Pop+ is at its regular price at Target. In the past year it sold for as little as $89 on Black Friday, and it has dropped each January after the holiday season. We expect $99–$109 in early January. If you can wait until then, you will likely save $20 to $30.",
            sources: [
                ProductSource(name: "Target", detail: "Listed price"),
                ProductSource(name: "Amazon", detail: "Comparison price"),
                ProductSource(name: "Keepa", detail: "Price history"),
            ]
        ),
    ]
}
