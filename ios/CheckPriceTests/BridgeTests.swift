// The Back Tap result and its way into the app: the four labels, the reason, the product link, the temporary
// screenshot rule, and that a real check keeps its own numbers and verdict.
import ShopperKit
import XCTest
@testable import Check_Price

final class CompactVerdictTests: XCTestCase {
    func testEachBackendVerdictKeepsItsOwnLabel() {
        let labels = ShopperKit.Verdict.allCases.map { Check_Price.Verdict($0).compactLabel }
        XCTAssertEqual(labels, ["BUY", "WAIT", "LOOK ELSEWHERE", "INDETERMINATE"])
        XCTAssertEqual(Check_Price.Verdict.alternative.compactSpokenLabel, "Look Elsewhere")
    }

    // Decision only: the popup carries the verdict, the product to open and the sample-data mark, and no reason.
    @MainActor
    func testTheSnippetCarriesOnlyTheDecision() throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("needs iOS 26") }
        let store = ThreadStore(threads: [])
        store.fetchReport = { _ in throw ShopperError.network }
        let snippet = VerdictSnippetIntent.record(.success(CheckResult(response: try Fixture.response())), in: store)
        XCTAssertEqual(snippet.verdict, Check_Price.Verdict.wait.rawValue)
        XCTAssertEqual(snippet.productId, "p1")
        XCTAssertNil(snippet.failure)
        XCTAssertFalse(snippet.isSampleData)
        XCTAssertEqual(store.threads.first?.product.summary, "Usually drops for Black Friday.")
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
    private let home = "/var/mobile/Containers/Data/Application/APP"
    private func kind(_ path: String) -> ScreenshotFile.Kind {
        ScreenshotFile.kind(ofPath: path, temp: home + "/tmp/", caches: home + "/Library/Caches")
    }

    func testTemporaryCopiesAreDeletable() {
        // Where Shortcuts left Take Screenshot's PNG on the real iPhone.
        XCTAssertEqual(kind("/var/mobile/tmp/com.apple.WorkflowKit.BackgroundShortcutRunner/Screenshot.png"), .shortcutsTemp)
        XCTAssertEqual(kind(home + "/tmp/shot.png"), .ownTemp)
        XCTAssertEqual(kind(home + "/Library/Caches/shot.png"), .ownCaches)
        XCTAssertFalse(ScreenshotFile.Kind.userStorage.isTemporary || ScreenshotFile.Kind.other.isTemporary)
    }

    func testAFolderNamedTmpIsNotATemporaryFolder() {
        for path in ["/var/mobile/Containers/Shared/AppGroup/X/File Provider Storage/tmp/receipt.png",
                     "/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/tmp/shot.png",
                     "/var/mobile/Containers/Data/Application/OTHER/tmp/shot.png",
                     "/var/mobile/Containers/Data/Application/OTHER/Library/Caches/shot.png",
                     "/var/mobile/tmpfiles/shot.png",
                     home + "/Documents/shot.png", home + "/Documents/tmp/shot.png", home + "/Library/shot.png",
                     "/var/mobile/Media/DCIM/100APPLE/IMG_0001.PNG", "/var/mobile/tmp/Documents/shot.png"] {
            XCTAssertFalse(kind(path).isTemporary, path)
        }
    }

    // On the real file system: a link or ".." in the temp folder is judged by where it really leads.
    func testLinksAndDotsAreResolvedBeforeJudging() throws {
        let files = FileManager.default
        let name = UUID().uuidString
        let temp = files.temporaryDirectory.appending(path: name + ".png")
        let kept = URL.documentsDirectory.appending(path: name + ".png")
        let link = files.temporaryDirectory.appending(path: name + "-link.png")
        try files.createDirectory(at: URL.documentsDirectory, withIntermediateDirectories: true)
        try Data([1]).write(to: temp)
        try Data([1]).write(to: kept)
        try files.createSymbolicLink(at: link, withDestinationURL: kept)
        defer { [temp, kept, link].forEach { try? files.removeItem(at: $0) } }

        XCTAssertEqual(ScreenshotFile.kind(of: temp), .ownTemp)
        XCTAssertEqual(ScreenshotFile.kind(of: link), .userStorage)
        XCTAssertEqual(ScreenshotFile.kind(of: files.temporaryDirectory.appending(path: "../Documents/" + name + ".png")), .userStorage)
    }
}

final class ScanDiagnosticsTests: XCTestCase {
    func testFactsCarryNoWordsFromTheScreenOrBackend() {
        let handoff = ScreenshotFile.Handoff(fileBacked: true, bytes: 1_400_000, kind: .shortcutsTemp, deleted: true)
        let failed = ScanDiagnostics.facts(source: "screenshot", result: .failure(.rejected("title: Sony WH-1000XM5")),
                                           handoff: handoff, ocr: 0.2, network: 1.5, total: 1.8)
        XCTAssertEqual(failed["error"] as? String, "rejected")
        XCTAssertEqual(failed["deleted"] as? Bool, true)
        XCTAssertEqual(failed["fileKind"] as? String, "shortcutsTemp")
        XCTAssertEqual(Set(failed.keys), ["source", "ok", "error", "ocr", "network", "total", "fileBacked", "bytes", "fileKind", "deleted"])
        XCTAssertFalse(failed.values.contains { ($0 as? String)?.contains("Sony") == true })
    }
}

// Fixtures: a check as the phone made it, and a report as the backend sends it.
private enum Fixture {
    static func response(productId: String? = "p1", verdict: String = "WAIT", reason: String = "Usually drops for Black Friday.") throws -> AnalyzeResponse {
        let id = productId.map { "\"productId\": \"\($0)\"," } ?? ""
        let json = "{\(id) \"verdict\": \"\(verdict)\", \"reason\": \"\(reason)\", \"confidence\": 0.6, \"isSampleData\": false}"
        return try JSONDecoder().decode(AnalyzeResponse.self, from: Data(json.utf8))
    }

    static func check(productId: String? = "p1", price: Double? = 349, retailer: String = "Target", verdict: String = "WAIT",
                      reason: String = "Usually drops for Black Friday.") throws -> Product {
        var extract = ExtractionResult()
        extract.currentPrice = price
        extract.retailer = retailer.isEmpty ? nil : retailer
        return CheckResult(response: try response(productId: productId, verdict: verdict, reason: reason), extract: extract).product
    }

    static func day(_ daysAgo: Double) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: Date().addingTimeInterval(-daysAgo * 86_400))
    }

    // One store's history ending at `latest`, and an analysis made for a scan at `scanPrice`.
    static func report(_ productId: String = "p1", retailer: String = "target", latest: Double = 349, seen: String = day(0),
                       scanPrice: Double? = 349, verdict: String = "WAIT", reason: String = "Full: wait for Black Friday.",
                       pending: Bool = false) throws -> ReportResponse {
        let json = """
        {"product": {"productId": "\(productId)", "title": "Bose QuietComfort Ultra"}, "pending": \(pending),
         "chart": {"series": [{"retailer": "\(retailer)", "points": [{"date": "2026-01-02", "price": 279, "source": "t"}, {"date": "\(seen)", "price": \(latest), "source": "t"}],
                               "lowest": 279, "latest": \(latest)}],
                   "lowest": {"price": 279, "date": "2026-01-02", "retailer": "\(retailer)"}, "typicalPrice": 329, "sources": {"serpapi": 1, "keepa": 12}, "isSampleData": false},
         "analysis": {"tier": "full", "scanPrice": \(scanPrice.map { String($0) } ?? "null"), "verdict": "\(verdict)", "confidence": 0.7, "reason": "\(reason)", "isSampleData": false,
                      "report": {"recommendation": {"reasoning": "Long: \(reason)"}},
                      "insights": {"forecast": {"outlook": "likely_lower", "low": 299, "high": 309, "byDate": "2026-11-27", "confidence": 0.6}}}}
        """
        return try JSONDecoder().decode(ReportResponse.self, from: Data(json.utf8))
    }
}

// A real check keeps its own price, store and verdict, and never gets demo numbers.
@MainActor
final class RealCheckTests: XCTestCase {
    func testDemoProductsKeepDemoHistoryButCheckedOnesNeverGetIt() throws {
        XCTAssertNotNil(ThreadDetailFigures.forThread(product: Demo.headphones, report: nil))
        let unmatched = try Fixture.check(productId: nil, price: nil, verdict: "INVESTIGATE")
        XCTAssertNil(ThreadDetailFigures.forThread(product: unmatched, report: nil))
        let matched = try Fixture.check()
        XCTAssertNil(ThreadDetailFigures.forThread(product: matched, report: nil))
        XCTAssertNil(ThreadDetailFigures.forThread(product: matched, report: try Fixture.report("p2")))
    }

    func testAnAnalysisForTheSamePriceRefinesTheCheck() throws {
        let report = try Fixture.report()
        let product = try Fixture.check().updated(with: report)
        let figures = try XCTUnwrap(ThreadDetailFigures.forThread(product: product, report: report))
        XCTAssertEqual(figures.current, 349)
        XCTAssertEqual(figures.typical, 329)
        XCTAssertEqual(figures.low, 279)
        XCTAssertEqual(figures.predictedLow, 299...309)
        XCTAssertEqual(figures.history.map(\.price), [279, 349])
        XCTAssertEqual(product.price, "$349")
        XCTAssertEqual(product.projectedLow, "$299–$309")
        XCTAssertEqual(product.summary, "Full: wait for Black Friday.")
    }

    // /report returns the product's newest analysis, which may be another scan's at another price.
    func testAnotherScansAnalysisDoesNotReplaceThisChecksVerdict() throws {
        let report = try Fixture.report(latest: 179, scanPrice: 179, verdict: "BUY_NOW", reason: "At $179 this is near the low.")
        let check = try Fixture.check()
        let product = check.updated(with: report).updated(with: report)
        XCTAssertEqual(product.verdict, .wait)
        XCTAssertEqual(product.summary, "Usually drops for Black Friday.")
        XCTAssertEqual(product.price, "$349")
        XCTAssertEqual(product.projectedLow, "")
        XCTAssertEqual(product.id, check.id)
        let figures = try XCTUnwrap(ThreadDetailFigures.forThread(product: product, report: report))
        XCTAssertFalse(figures.hasForecast)
        XCTAssertEqual(figures.current, 349)
        XCTAssertEqual(figures.history.map(\.price), [279, 179])
        // A link check (no price) is not refined by an analysis made for a priced scan either.
        XCTAssertEqual(try Fixture.check(price: nil).updated(with: report).verdict, .wait)
    }

    // The detail page's Why and Sources: the report's own words and sources, and only for this check's price.
    func testWhyAndSourcesComeFromTheMatchingReportOrStayEmpty() throws {
        let check = try Fixture.check()
        XCTAssertTrue(check.reasoning.isEmpty && check.sources.isEmpty && check.image == nil)
        let report = try Fixture.report()
        let refined = check.updated(with: report)
        XCTAssertEqual(refined.reasoning, "Long: Full: wait for Black Friday.")
        let figures = try XCTUnwrap(ThreadDetailFigures.forThread(product: refined, report: report))
        XCTAssertEqual(figures.sources, [ProductSource(name: "keepa", detail: "12 prices"), ProductSource(name: "serpapi", detail: "1 price")])

        let other = try Fixture.report(latest: 179, scanPrice: 179, reason: "At $179 this is near the low.")
        XCTAssertEqual(refined.updated(with: other).reasoning, "")
        XCTAssertEqual(check.updated(with: try Fixture.report(pending: true)).reasoning, "")
    }

    func testALinkGetsTodaysPriceOnlyFromItsOwnStore() throws {
        let link = try Fixture.check(price: nil, retailer: "Bestbuy")
        let sameStore = link.updated(with: try Fixture.report(retailer: "bestbuy", latest: 249.99, scanPrice: nil))
        XCTAssertEqual(sameStore.price, "$249.99")
        XCTAssertEqual(sameStore.retailer, "Bestbuy")

        let otherStore = try Fixture.report(retailer: "target", latest: 179.99, scanPrice: nil)
        XCTAssertEqual(link.updated(with: otherStore).price, "")
        XCTAssertNil(ThreadDetailFigures.forThread(product: link.updated(with: otherStore), report: otherStore))

        let stale = link.updated(with: try Fixture.report(retailer: "bestbuy", latest: 249.99, seen: Fixture.day(30), scanPrice: nil))
        XCTAssertEqual(stale.price, "")

        // No store named: the lowest fresh price comes with its own store.
        let unnamed = try Fixture.check(price: nil, retailer: "").updated(with: otherStore)
        XCTAssertEqual(unnamed.price, "$179.99")
        XCTAssertEqual(unnamed.retailer, "target")
        XCTAssertTrue(StoreName.same("Best Buy", "bestbuy.com") && !StoreName.same("Best Buy", "Target") && !StoreName.same("", ""))
    }

    func testAReportForAnotherProductIsNotAttached() async throws {
        let store = ThreadStore(threads: [])
        let other = try Fixture.report("p2")
        store.fetchReport = { _ in other }
        let id = store.startThread(for: try Fixture.check())
        store.loadReport(for: id)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertNil(store.thread(id)?.report)
        XCTAssertEqual(store.thread(id)?.product.verdict, .wait)
    }

    // An older load that answers late must not replace what a newer load installed.
    func testANewerReportLoadWins() async throws {
        let store = ThreadStore(threads: [])
        let old = try Fixture.report(reason: "old"), new = try Fixture.report(reason: "new")
        var calls = 0
        store.fetchReport = { _ in
            calls += 1
            if calls == 1 {
                try await Task.sleep(for: .milliseconds(300))
                return old
            }
            return new
        }
        let id = store.startThread(for: try Fixture.check())
        store.loadReport(for: id)
        try await Task.sleep(for: .milliseconds(50))
        store.loadReport(for: id)
        try await Task.sleep(for: .milliseconds(600))
        XCTAssertEqual(store.thread(id)?.product.summary, "new")
    }

    func testAFailedCheckShowsItsMessageAndNothingElse() throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("needs iOS 26") }
        let store = ThreadStore(threads: [])
        let snippet = VerdictSnippetIntent.record(.failure(.notConfigured), in: store)
        XCTAssertNil(snippet.verdict)
        XCTAssertNil(snippet.productId)
        XCTAssertEqual(snippet.failure, ShopperError.notConfigured.message)
        XCTAssertTrue(store.threads.isEmpty)
    }

    func testAnUnmatchedCheckHasNoDetailsButton() throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("needs iOS 26") }
        let store = ThreadStore(threads: [])
        let snippet = VerdictSnippetIntent.record(.success(CheckResult(response: try Fixture.response(productId: nil, verdict: "INVESTIGATE"))), in: store)
        XCTAssertEqual(snippet.verdict, Check_Price.Verdict.investigate.rawValue)
        XCTAssertNil(snippet.productId)
        XCTAssertEqual(store.threads.count, 1)
    }

    func testABuildWithoutAKeyFailsInsteadOfShowingADemo() async throws {
        guard (Backend.config.apiKey ?? "").isEmpty else { throw XCTSkip("this build has a backend key") }
        let result = await CheckRunner.run(url: URL(string: "https://www.bestbuy.com/site/x/1.p")!)
        guard case .failure(.notConfigured) = result else { return XCTFail("expected notConfigured, got \(result)") }
    }
}

@MainActor
final class OpenProductTests: XCTestCase {
    func testOpensTheNewestCheckOfTheProduct() throws {
        let store = ThreadStore(threads: [])
        store.fetchReport = { _ in throw ShopperError.network }
        store.startThread(for: try Fixture.check(reason: "older"))
        let newest = store.startThread(for: try Fixture.check(reason: "newest"))
        store.startThread(for: try Fixture.check(productId: "p2"))

        store.openProduct("p1")

        XCTAssertEqual(store.openThreadID, newest)
        XCTAssertEqual(store.threads.count, 3)
    }

    func testAProductNeverCheckedHereOpensNothing() {
        let store = ThreadStore(threads: DemoThreads.all)
        store.openProduct("missing")
        XCTAssertNil(store.openThreadID)
        XCTAssertEqual(store.threads.count, DemoThreads.all.count)
    }

    // The app restarted between the check and the tap on Details: the check itself comes back, not a rebuilt one.
    func testAfterARestartDetailsOpensTheSameCheck() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: file) }
        let archive = ScanArchive(file: file)
        let before = ThreadStore(threads: DemoThreads.all, archive: archive)
        before.fetchReport = { _ in throw ShopperError.network }
        let id = before.startThread(for: try Fixture.check(price: 198, retailer: "Best Buy", verdict: "BUY_NOW", reason: "Matches its low."))

        let kept = archive.load()
        XCTAssertEqual(kept.map(\.id), [id])
        let after = ThreadStore(threads: kept + DemoThreads.all, archive: archive)
        after.fetchReport = { _ in throw ShopperError.network }
        after.openProduct("p1")

        let thread = try XCTUnwrap(after.thread(id))
        XCTAssertEqual(after.openThreadID, id)
        XCTAssertEqual(thread.product.price, "$198")
        XCTAssertEqual(thread.product.retailer, "Best Buy")
        XCTAssertEqual(thread.product.verdict, .buyNow)
        XCTAssertEqual(thread.product.summary, "Matches its low.")
        XCTAssertEqual(thread.product.name, "Product")
    }
}
