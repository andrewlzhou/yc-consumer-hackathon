// Four verdicts, a product, and the demo products the screens start with.
// Verdict words, symbols and colours live in DesignSystem/VerdictStyle.swift.
import SwiftUI

enum Verdict: String { case buyNow = "BUY NOW", wait = "WAIT", alternative = "CONSIDER ALTERNATIVE", investigate = "INVESTIGATE" }

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
}

enum Demo {
    static let headphones = Product(name: "QuietComfort Ultra Headphones", retailer: "Amazon", price: "$349", icon: "headphones", verdict: .wait, summary: "Likely ~$40 less by Cyber Monday.", projectedLow: "$309–$319")
    static let saved = [
        Product(name: "AirPods Pro (2nd gen)", retailer: "Best Buy", price: "$189", icon: "airpodspro", verdict: .buyNow, summary: "Within $10 of its lowest price.", projectedLow: "$179–$189"),
        Product(name: "Nespresso Vertuo Pop+", retailer: "Target", price: "$129", icon: "cup.and.saucer.fill", verdict: .wait, summary: "Usually drops after the holidays.", projectedLow: "$99–$109")
    ]
}
