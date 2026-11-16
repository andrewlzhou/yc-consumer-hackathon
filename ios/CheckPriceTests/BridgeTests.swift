// The Back Tap result and its way into the app: the four labels, the short reason, the product link, and which
// thread a product opens.
import ShopperKit
import XCTest
@testable import Check_Price

final class CompactVerdictTests: XCTestCase {
    func testEachBackendVerdictKeepsItsOwnLabel() {
        let labels = ShopperKit.Verdict.allCases.map { Check_Price.Verdict($0).compactLabel }
        XCTAssertEqual(labels, ["BUY", "WAIT", "LOOK ELSEWHERE", "INDETERMINATE"])
        XCTAssertEqual(Check_Price.Verdict.alternative.compactSpokenLabel, "Look Elsewhere")
    }

    func testLongReasonKeepsWholeClauses() {
        let reason = "At $198, these Sony headphones match their recorded low and beat the past Black Friday price of $248."
        XCTAssertEqual(ShortReason.make(reason), "At $198, these Sony headphones match their recorded low")
    }

    func testShortReasonIsKeptWithoutItsFullStop() {
        XCTAssertEqual(ShortReason.make("Near its lowest price."), "Near its lowest price")
        XCTAssertEqual(ShortReason.make("Was $199.99 last week. Prices vary a lot."), "Was $199.99 last week")
    }

    func testReasonWithNoBreakIsCutAtAWordWithAnEllipsis() {
        let reason = "Recorded prices from three retailers over twelve months show nothing unusual about todays price whatsoever"
        let short = ShortReason.make(reason)
        XCTAssertTrue(short.hasSuffix("…"))
        XCTAssertLessThanOrEqual(short.count, ShortReason.maxCharacters + 1)
        XCTAssertTrue(reason.hasPrefix(String(short.dropLast())))
    }
}

final class ProductLinkTests: XCTestCase {
    func testRoundTripCarriesOnlyTheProductId() throws {
        let url = try XCTUnwrap(ProductLink.url(productId: "k171yx6pjhn5zs06hxd7twpqhh8j8hps"))
        XCTAssertEqual(url.absoluteString, "checkprice://product/k171yx6pjhn5zs06hxd7twpqhh8j8hps")
        XCTAssertEqual(ProductLink.productId(from: url), "k171yx6pjhn5zs06hxd7twpqhh8j8hps")
    }

    func testRefusesAnythingElse() {
        XCTAssertNil(ProductLink.url(productId: "Sony WH-1000XM5 $198"))
        XCTAssertNil(ProductLink.url(productId: ""))
        XCTAssertNil(ProductLink.url(productId: String(repeating: "a", count: 65)))
        for link in ["https://product/k171", "checkprice://thread/k171", "checkprice://product/k171/extra",
                     "checkprice://product/k171?title=Sony", "checkprice://product/"] {
            XCTAssertNil(ProductLink.productId(from: URL(string: link)!), link)
        }
    }
}

final class ScreenshotFileTests: XCTestCase {
    func testDeletesOnlyTemporaryCopies() {
        XCTAssertTrue(ScreenshotFile.isTemporary("/private/var/mobile/tmp/com.apple.WorkflowKit.BackgroundShortcutRunner/Screenshot.png"))
        XCTAssertTrue(ScreenshotFile.isTemporary("/private/var/mobile/Containers/Data/Application/X/Library/Caches/shot.png"))
        XCTAssertFalse(ScreenshotFile.isTemporary("/private/var/mobile/Containers/Data/Application/X/Documents/shot.png"))
        XCTAssertFalse(ScreenshotFile.isTemporary("/private/var/mobile/Containers/Shared/AppGroup/X/File Provider Storage/shot.png"))
        XCTAssertFalse(ScreenshotFile.isTemporary("/private/var/mobile/Media/DCIM/100APPLE/IMG_0001.PNG"))
    }
}

@MainActor
final class OpenProductTests: XCTestCase {
    private func report(_ productId: String, title: String = "Sony WH-1000XM5", pending: Bool = false) throws -> ReportResponse {
        let json = """
        {"product": {"productId": "\(productId)", "title": "\(title)"}, "pending": \(pending),
         "analysis": {"tier": "full", "verdict": "WAIT", "confidence": 0.7, "reason": "About $40 less by Cyber Monday.", "isSampleData": false}}
        """
        return try JSONDecoder().decode(ReportResponse.self, from: Data(json.utf8))
    }

    private func checked(_ productId: String, name: String) -> Product {
        Product(name: name, retailer: "Best Buy", price: "$198", icon: "tag", verdict: .buyNow, summary: "", projectedLow: "", productId: productId)
    }

    func testOpensTheNewestThreadForTheProduct() async throws {
        let store = ThreadStore(threads: [])
        let stub = try report("p1")
        store.fetchReport = { _ in stub }
        store.startThread(for: checked("p1", name: "older scan"))
        let newest = store.startThread(for: checked("p1", name: "newest scan"))
        store.startThread(for: checked("p2", name: "other product"))

        await store.openProduct("p1")

        XCTAssertEqual(store.openThreadID, newest)
        XCTAssertEqual(store.threads.count, 3)
    }

    func testColdStartBuildsTheThreadFromTheReport() async throws {
        let store = ThreadStore(threads: [])
        let stub = try report("p1")
        store.fetchReport = { _ in stub }

        await store.openProduct("p1")
        await store.openProduct("p1")

        let thread = try XCTUnwrap(store.threads.first)
        XCTAssertEqual(store.threads.count, 1)
        XCTAssertEqual(store.openThreadID, thread.id)
        XCTAssertEqual(thread.product.productId, "p1")
        XCTAssertEqual(thread.product.name, "Sony WH-1000XM5")
        XCTAssertEqual(thread.product.verdict, .wait)
        XCTAssertNotNil(thread.report)
    }

    func testUnknownProductOpensNothing() async {
        let store = ThreadStore(threads: [])
        store.fetchReport = { _ in throw ShopperError.server(404) }

        await store.openProduct("missing")

        XCTAssertNil(store.openThreadID)
        XCTAssertTrue(store.threads.isEmpty)
    }
}
