import Foundation
import OSLog
import ShopperKit

let log = Logger(subsystem: "dev.yccohack.worthit", category: "scan")

struct StageTimes: Codable {
    var ocr: Double = 0
    var extract: Double = 0
    var model: Double = 0
    var network: Double = 0
    var total: Double = 0
}

struct ScanOutcome {
    var extract = ExtractionResult()
    var response: AnalyzeResponse?
    var error: ShopperError?
    var times = StageTimes()
    var usedModel = false
    var tempFileDeleted: Bool?

    var dialog: String {
        if let response {
            let sample = response.isSampleData ? " (sample data)" : ""
            return "\(response.verdict.label): \(response.reason)\(sample)"
        }
        return error?.message ?? ShopperError.noProduct.message
    }
}

// Screenshot or link -> on-device extract -> POST /analyze. Image bytes stay in this function's memory.
enum ScanPipeline {
    static func run(imageData: Data, deviceId: String) async -> ScanOutcome {
        let start = Date()
        var outcome = ScanOutcome()
        guard let image = TextRecognizer.cgImage(from: imageData) else {
            outcome.error = .noProduct
            return outcome
        }
        let lines: [OCRLine]
        do {
            lines = try await TextRecognizer.recognize(image)
        } catch {
            outcome.error = .noProduct
            return outcome
        }
        outcome.times.ocr = Date().timeIntervalSince(start)
        let extractStart = Date()
        outcome.extract = ProductExtractor.extract(lines)
        outcome.times.extract = Date().timeIntervalSince(extractStart)
        if !outcome.extract.isListing && (outcome.extract.title == nil || outcome.extract.currentPrice == nil) {
            let modelStart = Date()
            if let refined = await ModelAssist.refine(lines: lines, current: outcome.extract) {
                outcome.extract = refined
                outcome.usedModel = true
            }
            outcome.times.model = Date().timeIntervalSince(modelStart)
        }
        guard outcome.extract.hasProduct else {
            outcome.error = .noProduct
            outcome.times.total = Date().timeIntervalSince(start)
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
        log.info("scan \(source, privacy: .public) ok=\(outcome.response != nil, privacy: .public) ocr=\(t.ocr, privacy: .public) model=\(t.model, privacy: .public) network=\(t.network, privacy: .public) total=\(t.total, privacy: .public)")
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
