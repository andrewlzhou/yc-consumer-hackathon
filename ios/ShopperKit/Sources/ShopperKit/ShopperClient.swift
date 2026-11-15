import Foundation

public struct BackendConfig: Sendable {
    public var baseURL: URL
    public var apiKey: String?
    public var analyzeTimeout: TimeInterval = 5
    public var readTimeout: TimeInterval = 8

    public init(baseURL: URL, apiKey: String?) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
}

public enum ShopperError: Error, Equatable, Sendable {
    case noProduct
    case notConfigured
    case unauthorized
    case rateLimited
    case timeout
    case network
    case rejected(String)
    case server(Int)
    case badResponse

    public var message: String {
        switch self {
        case .noProduct: "No product found. Open a product page and try again."
        case .notConfigured: "This build has no backend key. Add it to ios/Config/Secrets.xcconfig and rebuild."
        case .unauthorized: "The price service refused this app's key (401)."
        case .rateLimited: "Too many checks right now (429). Try again in a minute."
        case .timeout: "The price check took too long. Try again."
        case .network: "No connection to the price service. Check your network and try again."
        case let .rejected(reason): "The price service could not use this request: \(reason)"
        case let .server(code): "The price service had a problem (\(code)). Try again."
        case .badResponse: "The price service sent an answer this app cannot read."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .timeout, .network: true
        case let .server(code): code >= 500
        default: false
        }
    }
}

// What to do with a watched product's target price: keep it, set it, or clear it.
public enum TargetPriceChange: Sendable {
    case keep, set(Double), clear
}

// Thin HTTP client for the Convex routes. One bounded retry for timeouts, dropped connections and 5xx.
public struct ShopperClient: Sendable {
    public var config: BackendConfig
    public var deviceId: String
    private let session: URLSession

    public init(config: BackendConfig, deviceId: String, session: URLSession = .shared) {
        self.config = config
        self.deviceId = deviceId
        self.session = session
    }

    public func analyze(_ extract: ProductExtract) async throws -> AnalyzeResponse {
        try await send("POST", "analyze", body: try JSONEncoder().encode(extract), timeout: config.analyzeTimeout)
    }

    public func report(productId: String) async throws -> ReportResponse {
        try await send("GET", "report", query: ["productId": productId], timeout: config.readTimeout)
    }

    public func watchlist() async throws -> [WatchItem] {
        try await send("GET", "watchlist", query: ["deviceId": deviceId], timeout: config.readTimeout)
    }

    public func save(productId: String, target: TargetPriceChange = .keep, prefs: WatchPrefs? = nil) async throws {
        var body: [String: Any] = ["deviceId": deviceId, "productId": productId]
        switch target {
        case .keep: break
        case let .set(price): body["targetPrice"] = price
        case .clear: body["targetPrice"] = NSNull()
        }
        if let prefs, let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(prefs)) as? [String: Bool] {
            body["prefs"] = encoded
        }
        let _: Ignored = try await send("POST", "watchlist/save", body: try JSONSerialization.data(withJSONObject: body), timeout: config.readTimeout)
    }

    public func remove(productId: String) async throws {
        let body = try JSONEncoder().encode(["deviceId": deviceId, "productId": productId])
        let _: Ignored = try await send("POST", "watchlist/remove", body: body, timeout: config.readTimeout)
    }

    public func inbox() async throws -> [InboxNotification] {
        try await send("GET", "watchlist/notifications", query: ["deviceId": deviceId], timeout: config.readTimeout)
    }

    public func acknowledge(ids: [String]) async throws {
        struct Body: Encodable { var deviceId: String; var ids: [String] }
        let _: Ignored = try await send("POST", "watchlist/notifications/ack", body: try JSONEncoder().encode(Body(deviceId: deviceId, ids: ids)), timeout: config.readTimeout)
    }

    public func makeRequest(_ method: String, _ path: String, query: [String: String] = [:], body: Data? = nil, timeout: TimeInterval) throws -> URLRequest {
        guard let key = config.apiKey, !key.isEmpty else { throw ShopperError.notConfigured }
        var components = URLComponents(url: config.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var request = URLRequest(url: components.url!, timeoutInterval: timeout)
        request.httpMethod = method
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            request.httpBody = body
        }
        return request
    }

    private struct Ignored: Decodable {}

    private func send<Response: Decodable>(_ method: String, _ path: String, query: [String: String] = [:], body: Data? = nil, timeout: TimeInterval) async throws -> Response {
        let request = try makeRequest(method, path, query: query, body: body, timeout: timeout)
        do {
            return try await perform(request)
        } catch let error as ShopperError where error.isRetryable {
            return try await perform(request)
        }
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw error.code == .timedOut ? ShopperError.timeout : ShopperError.network
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300:
            do { return try JSONDecoder().decode(Response.self, from: data) } catch { throw ShopperError.badResponse }
        case 401: throw ShopperError.unauthorized
        case 429: throw ShopperError.rateLimited
        case 400..<500:
            let reason = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "status \(status)"
            throw ShopperError.rejected(reason)
        default: throw ShopperError.server(status)
        }
    }
}
