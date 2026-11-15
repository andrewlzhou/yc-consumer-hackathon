import Foundation
import OSLog
import ShopperKit

let log = Logger(subsystem: "dev.yccohack.worthit", category: "scan")

struct StageTimes: Codable {
    var ocr: Double = 0
    var extract: Double = 0
    var network: Double = 0
    var total: Double = 0
    var imageBytes = 0
    var ocrLines = 0
}

struct ScanOutcome {
    var extract = ExtractionResult()
    var response: AnalyzeResponse?
    var error: ShopperError?
    var times = StageTimes()
    var tempFileDeleted: Bool?

    var dialog: String {
        if let response {
            return "\(response.verdict.label): \(response.reason)"
        }
        return error?.message ?? ShopperError.noProduct.message
    }
}

// Screenshot or link -> on-device extract -> POST /analyze. Image bytes stay in this function's memory.
enum ScanPipeline {
    static func run(imageData: Data, deviceId: String) async -> ScanOutcome {
        let start = Date()
        var outcome = ScanOutcome()
        outcome.times.imageBytes = imageData.count
        guard let image = TextRecognizer.cgImage(from: imageData) else {
            outcome.error = .unreadableImage
            record(outcome, source: "screenshot")
            return outcome
        }
        let lines: [OCRLine]
        do {
            lines = try await TextRecognizer.recognize(image)
        } catch {
            outcome.error = .unreadableImage
            record(outcome, source: "screenshot")
            return outcome
        }
        outcome.times.ocr = Date().timeIntervalSince(start)
        outcome.times.ocrLines = lines.count
        let extractStart = Date()
        outcome.extract = ProductExtractor.extract(lines)
        outcome.times.extract = Date().timeIntervalSince(extractStart)
        guard outcome.extract.hasProduct else {
            outcome.error = .noProduct
            outcome.times.total = Date().timeIntervalSince(start)
            record(outcome, source: "screenshot")
            return outcome
        }
        let e = outcome.extract
        let request = ProductExtract(deviceId: deviceId, retailer: e.retailer, title: e.title, currentPrice: e.currentPrice,
                                     originalPrice: e.originalPrice, ocrLines: e.title == nil ? e.fallbackLines : nil,
                                     capturedAt: (start.timeIntervalSince1970 * 1000).rounded())
        await send(request, into: &outcome, deviceId: deviceId)
        outcome.times.total = Date().timeIntervalSince(start)
        record(outcome, source: "screenshot")
        return outcome
    }

    static func run(url: URL, deviceId: String) async -> ScanOutcome {
        let start = Date()
        var outcome = ScanOutcome()
        let request = ProductExtract(deviceId: deviceId, url: url.absoluteString, capturedAt: (start.timeIntervalSince1970 * 1000).rounded())
        await send(request, into: &outcome, deviceId: deviceId)
        // A new link is resolved in the background; asking once more shortly after usually returns the product.
        if outcome.response?.productId == nil && outcome.response?.reportStatus == "pending" {
            try? await Task.sleep(for: .seconds(2))
            await send(request, into: &outcome, deviceId: deviceId)
        }
        outcome.times.total = Date().timeIntervalSince(start)
        record(outcome, source: "link")
        return outcome
    }

    private static func send(_ request: ProductExtract, into outcome: inout ScanOutcome, deviceId: String) async {
        let client = ShopperClient(config: AppModel.config, deviceId: deviceId)
        let networkStart = Date()
        do {
            outcome.response = try await client.analyze(request)
        } catch let error as ShopperError {
            outcome.error = error
        } catch {
            outcome.error = .network
        }
        outcome.times.network = Date().timeIntervalSince(networkStart)
    }

    // Keeps the last 100 runs' stage times (no content) so Setup can show p50/p95 measured on this phone.
    static func record(_ outcome: ScanOutcome, source: String) {
        let t = outcome.times
        log.info("scan \(source, privacy: .public) ok=\(outcome.response != nil, privacy: .public) bytes=\(t.imageBytes, privacy: .public) lines=\(t.ocrLines, privacy: .public) ocr=\(t.ocr, privacy: .public) network=\(t.network, privacy: .public) total=\(t.total, privacy: .public)")
        var runs = TimingLog.load()
        runs.append(TimingLog.Run(source: source, ok: outcome.response != nil, times: t))
        TimingLog.save(Array(runs.suffix(100)))
    }
}

enum TimingLog {
    struct Run: Codable {
        var source: String
        var ok: Bool
        var times: StageTimes
    }

    static func load() -> [Run] {
        guard let data = UserDefaults.standard.data(forKey: "shopper.timings") else { return [] }
        return (try? JSONDecoder().decode([Run].self, from: data)) ?? []
    }

    static func save(_ runs: [Run]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(runs), forKey: "shopper.timings")
    }

    static func percentile(_ values: [Double], _ p: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[min(sorted.count - 1, Int((Double(sorted.count - 1) * p).rounded()))]
    }
}
