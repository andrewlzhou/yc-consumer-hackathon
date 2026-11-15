// Target membership: app only.
import Foundation

enum ScanAPI {
    // Your Convex HTTP actions URL. It ends in .convex.site (not .convex.cloud).
    // While this still says YOUR-DEPLOYMENT, every call returns sample data, so the UI runs with no backend.
    static let baseURL = URL(string: "https://YOUR-DEPLOYMENT.convex.site")!

    static var useMocks: Bool { baseURL.host?.contains("YOUR-DEPLOYMENT") ?? true }
    nonisolated(unsafe) private static var mockStarted: [String: Date] = [:]

    static var deviceId: String {
        let k = "notyet.deviceId"
        if let id = UserDefaults.standard.string(forKey: k) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: k)
        return id
    }

    struct Quick: Decodable {
        let scanKey: String
        let productName: String
        let verdict: String
        let oneLiner: String
        let retailer: String?
    }

    // MARK: Scans

    static func submit(imageData: Data, scanKey: String, needBy: String? = nil, timeout: TimeInterval) async throws -> Quick {
        if useMocks { return await mockQuick(scanKey) }
        var req = URLRequest(url: baseURL.appending(path: "scan"))
        req.httpMethod = "POST"
        req.timeoutInterval = timeout
        req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        req.setValue(deviceId, forHTTPHeaderField: "x-device-id")
        req.setValue(scanKey, forHTTPHeaderField: "x-scan-key")
        if let needBy { req.setValue(needBy, forHTTPHeaderField: "x-need-by") }
        req.httpBody = imageData
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(Quick.self, from: data)
    }

    static func fetchScan(key: String) async throws -> ScanResponse {
        if useMocks { return mockScan(key) }
        var comps = URLComponents(url: baseURL.appending(path: "scan"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "key", value: key)]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        return try JSONDecoder().decode(ScanResponse.self, from: data)
    }

    /// Search tab: free text, returns the same quick verdict. Open the report with Router.shared.openKey = result.scanKey
    static func ask(_ q: String, needBy: String? = nil) async throws -> Quick {
        if useMocks { return await mockQuick(UUID().uuidString) }
        var req = URLRequest(url: baseURL.appending(path: "ask"))
        req.httpMethod = "POST"
        req.timeoutInterval = 40
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body = ["q": q, "deviceId": deviceId]
        if let needBy { body["needBy"] = needBy }
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(Quick.self, from: data)
    }

    // MARK: Lists

    static func fetchHistory() async throws -> [HistoryItem] {
        if useMocks { return SampleData.history }
        return try await get("history", ["deviceId": deviceId])
    }

    static func fetchWishlist() async throws -> [WishlistItem] {
        if useMocks { return SampleData.wishlist }
        return try await get("wishlist", ["deviceId": deviceId])
    }

    /// kind: "lowest" or "deals"
    static func fetchDiscover(kind: String) async throws -> [DiscoverItem] {
        if useMocks { return SampleData.discover }
        return try await get("discover", ["kind": kind])
    }

    /// needBy is "YYYY-MM-DD". Saving again updates the date.
    static func saveToWishlist(key: String, needBy: String? = nil) async throws {
        if useMocks { return }
        var req = URLRequest(url: baseURL.appending(path: "wishlist"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["scanKey": key, "deviceId": deviceId, "needBy": needBy ?? ""])
        _ = try await URLSession.shared.data(for: req)
    }

    private static func get<T: Decodable>(_ path: String, _ query: [String: String]) async throws -> T {
        var comps = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: Mocks (no backend needed)

    private static func mockQuick(_ key: String) async -> Quick {
        mockStarted[key] = Date()
        try? await Task.sleep(for: .seconds(1.5))
        let r = SampleData.report
        return Quick(scanKey: key, productName: r.product.name, verdict: r.verdict,
                     oneLiner: r.oneLiner, retailer: r.whereToBuy?.retailer)
    }

    /// New keys show "Digging…" for 4 seconds, then the report. "b" and "c" show the other verdicts; "digging" never finishes.
    private static func mockScan(_ key: String) -> ScanResponse {
        let stillDigging = key == "digging" || (mockStarted[key].map { Date().timeIntervalSince($0) < 4 } ?? false)
        if stillDigging {
            let r = SampleData.report
            return ScanResponse(status: "deep", step: "Reading the price history…",
                                quick: QuickInfo(productName: r.product.name, verdict: r.verdict, oneLiner: r.oneLiner),
                                result: nil, error: nil)
        }
        return ScanResponse(status: "done", step: "Done", quick: nil, result: SampleData.result(for: key), error: nil)
    }
}
