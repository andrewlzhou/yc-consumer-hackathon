// Debug builds keep a few facts about the last Shortcut checks, so a device test can prove the temporary screenshot
// was deleted and how long each stage took. Booleans, sizes, categories and seconds only: nothing read from the
// screen, no file name or path, no key. Release builds record nothing.
// Read back over USB: `xcrun devicectl device copy from --domain-type appDataContainer --domain-identifier <bundle id>
// --source Library/Preferences/<bundle id>.plist`, key `checkprice.scans` (newest last); also in the device log.
import Foundation
import OSLog
import ShopperKit

enum ScanDiagnostics {
    static let key = "checkprice.scans"

    static func record(source: String, result: Result<CheckResult, ShopperError>, handoff: ScreenshotFile.Handoff?,
                       times: CheckRunner.Times, since start: Date) {
        #if DEBUG
        var run = facts(source: source, result: result, handoff: handoff, ocr: times.ocr, network: times.network,
                        total: Date().timeIntervalSince(start))
        Logger(subsystem: "com.ycconsumerhackathon.checkprice", category: "scan")
            .info("scan \(run.description, privacy: .public)")
        run["at"] = Date().timeIntervalSince1970
        let runs = (UserDefaults.standard.array(forKey: key) ?? []) + [run]
        UserDefaults.standard.set(Array(runs.suffix(50)), forKey: key)
        #endif
    }

    static func facts(source: String, result: Result<CheckResult, ShopperError>, handoff: ScreenshotFile.Handoff?,
                      ocr: Double, network: Double, total: Double) -> [String: Any] {
        var run: [String: Any] = ["source": source, "ocr": ocr, "network": network, "total": total]
        switch result {
        case let .success(check):
            run["ok"] = true
            run["matched"] = check.response.productId != nil
        case let .failure(error):
            run["ok"] = false
            run["error"] = code(error)
        }
        if let handoff {
            run["fileBacked"] = handoff.fileBacked
            run["bytes"] = handoff.bytes
            if let kind = handoff.kind { run["fileKind"] = kind.rawValue }
            if let deleted = handoff.deleted { run["deleted"] = deleted }
        }
        return run
    }

    // The failure's kind without the backend's own words.
    static func code(_ error: ShopperError) -> String {
        switch error {
        case .noProduct: "noProduct"
        case .unreadableImage: "unreadableImage"
        case .notConfigured: "notConfigured"
        case .unauthorized: "unauthorized"
        case .rateLimited: "rateLimited"
        case .timeout: "timeout"
        case .network: "network"
        case .rejected: "rejected"
        case let .server(status): "server\(status)"
        case .badResponse: "badResponse"
        }
    }
}
