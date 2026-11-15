import Foundation
import Testing
@testable import ShopperKit

// Regressions from the YCCO-11 review of 8467733: wrong prices and personal text leaving the phone.
private func line(_ text: String, _ x: Double, _ y: Double, _ w: Double, _ h: Double) -> OCRLine {
    OCRLine(text: text, x: x, y: y, w: w, h: h)
}

private let title = [line("AE Dreamy Drape Baggy Jean", 0.05, 0.50, 0.7, 0.024)]

@Test func strikeFirstOnOneLineSendsTheSalePrice() {
    let r = ProductExtractor.extract(title + [line("$59.95 $41.96", 0.05, 0.55, 0.5, 0.024)])
    #expect(r.currentPrice == 41.96 && r.originalPrice == 59.95 && r.hasProduct)
}

@Test func saleAndStruckPriceInSeparateBoxesAreNotAListing() {
    let r = ProductExtractor.extract(title + [line("$59.95", 0.05, 0.55, 0.2, 0.024), line("$41.96", 0.28, 0.55, 0.2, 0.024)])
    #expect(!r.isListing && r.currentPrice == 41.96 && r.originalPrice == 59.95)
}

@Test func twoUnrelatedBigPricesAreBlank() {
    let r = ProductExtractor.extract(title + [line("$41.96", 0.05, 0.55, 0.2, 0.024), line("$89.95", 0.05, 0.80, 0.2, 0.024)])
    #expect(r.currentPrice == nil)
}

@Test func flatSuperscriptAndLostCommaAreBlank() {
    for text in ["$27900", "$1099", "$1299", "$2799"] {
        let r = ProductExtractor.extract(title + [line(text, 0.05, 0.55, 0.2, 0.03)])
        #expect(r.currentPrice == nil, "\(text)")
    }
}

@Test func notificationBannerNeverBecomesATitle() {
    let r = ProductExtractor.extract([
        line("Messages now", 0.1, 0.06, 0.5, 0.015),
        line("Mom: are you picking up Sam at 5 today", 0.1, 0.085, 0.8, 0.018),
        line("$41.96", 0.05, 0.55, 0.2, 0.03),
    ])
    #expect(r.title == nil && r.fallbackLines.isEmpty && !r.hasProduct)
}

@Test func accountHeaderNeverBecomesATitle() {
    let r = ProductExtractor.extract([
        line("Hello, Ruhaan Singh", 0.05, 0.40, 0.6, 0.02),
        line("1600 Amphitheatre Pkwy apt 4", 0.05, 0.425, 0.6, 0.02),
        line("Deliver to 94043", 0.05, 0.45, 0.4, 0.015),
        line("$41.96", 0.05, 0.55, 0.2, 0.03),
    ])
    #expect(r.title == nil && r.fallbackLines.isEmpty && !r.hasProduct)
}

@Test func titleFarFromThePriceIsNotUsed() {
    let r = ProductExtractor.extract([line("Weekly ad specials for the holidays", 0.05, 0.10, 0.8, 0.025), line("$41.96", 0.05, 0.80, 0.2, 0.03)])
    #expect(r.title == nil)
}

@Test func fallbackLinesAreFewAndNearThePrice() {
    var lines = (0..<10).map { line("Line \($0) of words", 0.05, 0.40 + Double($0) * 0.02, 0.5, 0.012) }
    lines.append(line("Far away caption text", 0.05, 0.95, 0.5, 0.012))
    lines.append(line("$41.96", 0.05, 0.62, 0.2, 0.03))
    let r = ProductExtractor.extract(lines)
    #expect(r.fallbackLines.count <= 5 && !r.fallbackLines.contains("Far away caption text"))
    #expect(r.fallbackLines.allSatisfy { $0.utf16.count <= 200 })
}

@Test func variantAndPlanPricesAreNotOriginalPrices() {
    let base = [line("Sony WH-1000XM5 Wireless Headphones", 0.05, 0.45, 0.8, 0.022), line("$279.99", 0.05, 0.50, 0.3, 0.035)]
    let variant = ProductExtractor.extract(base + [line("Midnight Blue $299.99", 0.05, 0.545, 0.5, 0.015)])
    let plan = ProductExtractor.extract(base + [line("2-Year Plan $329.99", 0.05, 0.545, 0.5, 0.015)])
    #expect(variant.currentPrice == 279.99 && variant.originalPrice == nil)
    #expect(plan.currentPrice == 279.99 && plan.originalPrice == nil)
}

@Test func cartSubtotalIsNotAProductPrice() {
    let r = ProductExtractor.extract([
        line("Sony WH-1000XM5 Wireless Headphones", 0.05, 0.30, 0.8, 0.02), line("$279.99", 0.05, 0.34, 0.2, 0.02),
        line("Subtotal $329.98", 0.05, 0.70, 0.6, 0.03),
    ])
    #expect(!r.hasProduct && r.currentPrice == nil)
}

@Test func storeNameInsideTheTitleIsNotTheRetailer() {
    let r = ProductExtractor.extract([line("Amazon Echo Dot (5th Gen) Smart Speaker", 0.05, 0.45, 0.8, 0.022), line("$49.99", 0.05, 0.50, 0.2, 0.035)])
    #expect(r.title?.contains("Echo Dot") == true && r.retailer == nil)
}
