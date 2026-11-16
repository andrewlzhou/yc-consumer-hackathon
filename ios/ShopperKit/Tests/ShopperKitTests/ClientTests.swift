import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import ShopperKit

final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responses: [(Int, String)] = []
    nonisolated(unsafe) static var requests: [URLRequest] = []
    nonisolated(unsafe) static var bodies: [Data] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: 4096); if n <= 0 { break }; data.append(buffer, count: n) }
            Self.bodies.append(data)
        } else {
            Self.bodies.append(request.httpBody ?? Data())
        }
        let (status, body) = Self.responses.isEmpty ? (500, "{}") : Self.responses.removeFirst()
        if status == -1 {
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized) struct ClientTests {
    func client(_ responses: [(Int, String)], key: String? = "test-key") -> ShopperClient {
        StubProtocol.responses = responses
        StubProtocol.requests = []
        StubProtocol.bodies = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return ShopperClient(config: BackendConfig(baseURL: URL(string: "https://example.convex.site")!, apiKey: key),
                             deviceId: "test-device-1", session: URLSession(configuration: configuration))
    }

    let card = #"{"productId":"p1","matchedTitle":"Sony WH-1000XM5","verdict":"BUY_NOW","reason":"Lowest in 90 days.","confidence":0.8,"isSampleData":false,"reportStatus":"pending"}"#

    @Test func analyzeSendsOnlyExtractFieldsWithKey() async throws {
        let c = client([(200, card)])
        let response = try await c.analyze(ProductExtract(deviceId: c.deviceId, retailer: "Best Buy", title: "Sony WH-1000XM5", currentPrice: 279.99))
        #expect(response.verdict == .buyNow && response.productId == "p1" && response.reportStatus == "pending")
        let request = try #require(StubProtocol.requests.first)
        #expect(request.url?.path == "/analyze" && request.value(forHTTPHeaderField: "x-api-key") == "test-key")
        let body = try #require(JSONSerialization.jsonObject(with: StubProtocol.bodies[0]) as? [String: Any])
        #expect(Set(body.keys) == ["deviceId", "retailer", "title", "currentPrice"])
    }

    @Test func retriesOnceOnServerErrorThenSucceeds() async throws {
        let c = client([(502, "{}"), (200, card)])
        _ = try await c.analyze(ProductExtract(deviceId: c.deviceId, title: "x y z"))
        #expect(StubProtocol.requests.count == 2)
    }

    @Test func readRetryIsBounded() async throws {
        let c = client([(-1, ""), (-1, ""), (200, "[]")])
        await #expect(throws: ShopperError.timeout) { try await c.watchlist() }
        #expect(StubProtocol.requests.count == 2)
    }

    @Test func timedOutAnalyzeIsNotRepeated() async throws {
        let c = client([(-1, ""), (200, card)])
        await #expect(throws: ShopperError.timeout) { try await c.analyze(ProductExtract(deviceId: c.deviceId, title: "x y z")) }
        #expect(StubProtocol.requests.count == 1)
    }

    @Test func mapsAuthAndRateLimitWithoutRetry() async throws {
        let c = client([(401, #"{"error":"unauthorized"}"#)])
        await #expect(throws: ShopperError.unauthorized) { try await c.watchlist() }
        let d = client([(429, #"{"error":"rate limited"}"#)])
        await #expect(throws: ShopperError.rateLimited) { try await d.inbox() }
        #expect(StubProtocol.requests.count == 1)
        let e = client([(400, #"{"error":"title, ocrLines, or url is required"}"#)])
        await #expect(throws: ShopperError.rejected("title, ocrLines, or url is required")) { try await e.analyze(ProductExtract(deviceId: "d")) }
    }

    @Test func missingKeyFailsBeforeNetwork() async throws {
        let c = client([], key: nil)
        await #expect(throws: ShopperError.notConfigured) { try await c.watchlist() }
        #expect(StubProtocol.requests.isEmpty)
    }

    @Test func watchlistSaveSendsTargetAndClear() async throws {
        let c = client([(200, #"{"id":"w1"}"#), (200, #"{"id":"w1"}"#)])
        try await c.save(productId: "p1", target: .set(249))
        try await c.save(productId: "p1", target: .clear)
        let first = try #require(JSONSerialization.jsonObject(with: StubProtocol.bodies[0]) as? [String: Any])
        let second = try #require(JSONSerialization.jsonObject(with: StubProtocol.bodies[1]) as? [String: Any])
        #expect(first["targetPrice"] as? Double == 249 && second["targetPrice"] is NSNull)
    }

    @Test func decodesReportWatchlistAndInbox() async throws {
        let report = #"{"product":{"productId":"p1","title":"Sony WH-1000XM5","brand":"Sony","category":"headphones","provisional":false,"isSample":false},"pending":false,"chart":{"kind":"step","from":"2025-11-15","to":"2026-11-15","series":[{"retailer":"Best Buy","points":[{"date":"2026-01-01","price":329.99,"source":"api"}],"lowest":248,"latest":279.99}],"lowest":{"price":248,"date":"2025-11-28","retailer":"Amazon"},"typicalPrice":329.99,"events":[],"sources":{"api":12},"isSampleData":false},"analysis":{"analysisId":"a1","tier":"full","source":"model","model":"m","createdAt":1,"scanPrice":279.99,"verdict":"WAIT","confidence":0.6,"reason":"r","report":{"match":{"productId":"p1","confidence":1,"note":""},"verdict":"WAIT","confidence":0.6,"reason":"r","reasonEvidenceIds":[],"priceAssessment":{"summary":"s","evidenceIds":[]},"discount":{"status":"genuine","signals":[],"explanation":"e","evidenceIds":[]},"forecast":{"low":240,"high":260,"byDate":"2026-11-30","confidence":0.6,"explanation":"f","evidenceIds":[]},"retailers":{"summary":"s","evidenceIds":[]},"competitors":[],"recommendation":{"reasoning":"x","evidenceIds":[]}},"evidence":[],"groundingIssues":[],"isSampleData":false,"insights":null}}"#
        let c = client([(200, report), (200, #"[{"_id":"w1","deviceId":"test-device-1","productId":"p1","targetPrice":250,"prefs":{"target_hit":true,"new_low":true,"buy_now_flip":true,"sale_start":true,"better_alternative":false},"createdAt":1}]"#), (200, #"[{"id":"n1","productId":"p1","title":"Price drop","body":"b","price":240,"verdict":"BUY_NOW","trigger":"target_hit","simulated":true,"channel":"inbox","createdAt":2}]"#)])
        let r = try await c.report(productId: "p1")
        #expect(r.analysis?.report?.forecast?.low == 240 && r.chart?.series.first?.points.count == 1)
        #expect(StubProtocol.requests[0].url?.query == "productId=p1")
        let items = try await c.watchlist()
        #expect(items.first?.targetPrice == 250 && items.first?.prefs?.better_alternative == false)
        let inbox = try await c.inbox()
        #expect(inbox.first?.simulated == true)
    }
}
