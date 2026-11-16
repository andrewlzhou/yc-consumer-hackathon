// The Convex backend (main branch, convex/http.ts) through ShopperKit's client. The address and app key
// come from Info.plist, filled from ios/Config/*.xcconfig; the key lives only in the git-ignored
// ios/Config/Secrets.xcconfig. The device id is an anonymous random id, not an account.
import Foundation
import ShopperKit

enum Backend {
    static var config: BackendConfig {
        let info = Bundle.main.infoDictionary ?? [:]
        let host = (info["CheckPriceBackendHost"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "scintillating-caterpillar-190.convex.site"
        return BackendConfig(baseURL: URL(string: "https://" + host)!, apiKey: info["CheckPriceAPIKey"] as? String)
    }

    static var client: ShopperClient { ShopperClient(config: config, deviceId: DeviceIdentity.current()) }
}

// A finished check: the backend's verdict plus what the phone read, enough to start a thread.
struct CheckResult {
    let response: AnalyzeResponse
    var extract = ExtractionResult()
    var url: URL?

    var product: Product {
        Product(
            name: response.matchedTitle ?? extract.title ?? url?.host() ?? "Product",
            productId: response.productId,
            check: CheckSnapshot(price: extract.currentPrice, retailer: extract.retailer ?? url.map(Self.storeName) ?? "",
                                 verdict: Verdict(response.verdict), reason: response.reason, isSampleData: response.isSampleData)
        )
    }

    // "www.bestbuy.com" -> "Best Buy"-ish: the domain's main word, capitalised ("Bestbuy").
    private static func storeName(_ url: URL) -> String {
        let parts = (url.host() ?? "").split(separator: ".").filter { $0 != "www" && $0 != "m" }
        return parts.first.map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? ""
    }
}

// Screenshot or link -> on-device text reading -> POST /analyze. The image stays in memory here and
// never leaves the phone; only the extracted fields are sent (docs/backend/contract.md on main).
enum CheckRunner {
    // How long each stage took, for ScanDiagnostics.
    final class Times {
        var ocr = 0.0
        var network = 0.0
    }

    static func run(url: URL, times: Times? = nil) async -> Result<CheckResult, ShopperError> {
        let request = ProductExtract(deviceId: DeviceIdentity.current(), url: url.absoluteString, capturedAt: nowMillis())
        var result = await analyze(request, times)
        // A new link is resolved in the background; asking once more shortly after usually finds the product.
        if case let .success(response) = result, response.productId == nil, response.reportStatus == "pending" {
            try? await Task.sleep(for: .seconds(2))
            result = await analyze(request, times)
        }
        return result.map { CheckResult(response: $0, url: url) }
    }

    static func run(imageData: Data, times: Times? = nil) async -> Result<CheckResult, ShopperError> {
        let start = Date()
        guard let image = TextRecognizer.cgImage(from: imageData),
              let lines = try? await TextRecognizer.recognize(image) else { return .failure(.unreadableImage) }
        times?.ocr = Date().timeIntervalSince(start)
        let extract = ProductExtractor.extract(lines)
        guard extract.hasProduct else { return .failure(.noProduct) }
        let request = ProductExtract(deviceId: DeviceIdentity.current(), retailer: extract.retailer, title: extract.title,
                                     currentPrice: extract.currentPrice, originalPrice: extract.originalPrice,
                                     ocrLines: extract.title == nil ? extract.fallbackLines : nil, capturedAt: nowMillis())
        return await analyze(request, times).map { CheckResult(response: $0, extract: extract) }
    }

    private static func analyze(_ request: ProductExtract, _ times: Times?) async -> Result<AnalyzeResponse, ShopperError> {
        let start = Date()
        defer { times?.network += Date().timeIntervalSince(start) }
        do { return .success(try await Backend.client.analyze(request)) }
        catch let error as ShopperError { return .failure(error) }
        catch { return .failure(.network) }
    }

    private static func nowMillis() -> Double { (Date().timeIntervalSince1970 * 1000).rounded() }
}

enum Money {
    // "$198", or "$198.99" when there are cents.
    static func text(_ value: Double) -> String {
        value.rounded() == value ? "$\(Int(value))" : String(format: "$%.2f", value)
    }
}

extension Verdict {
    init(_ backend: ShopperKit.Verdict) {
        switch backend {
        case .buyNow: self = .buyNow
        case .wait: self = .wait
        case .considerAlternative: self = .alternative
        case .investigate: self = .investigate
        }
    }
}
