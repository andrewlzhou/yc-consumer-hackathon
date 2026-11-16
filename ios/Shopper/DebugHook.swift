#if DEBUG
import Foundation
import ShopperKit

// Debug builds only: lets a developer run checks over USB without touching the screen.
//   devicectl device process launch --device <id> dev.<you>.worthit -testDevice ios-test-<x> -checkLink <url> -checkImage <file>
// -checkImage names a file previously copied into the app's Documents folder; it is deleted after it is read.
// Results (verdicts, extracted fields, timings) go to Documents/debug-runs.json; nothing is logged.
enum DebugHook {
    struct Run: Codable {
        var input: String
        var verdict: String?
        var productId: String?
        var matchedTitle: String?
        var reason: String?
        var isSampleData: Bool?
        var reportStatus: String?
        var error: String?
        var extract: [String: String]
        var times: StageTimes
        var at: Date
    }

    @MainActor
    static func runIfRequested(_ model: AppModel) async {
        let args = ProcessInfo.processInfo.arguments
        var inputs: [(String, String)] = []
        for (i, arg) in args.enumerated() where i + 1 < args.count {
            if ["-checkLink", "-checkImage", "-testDevice"].contains(arg) { inputs.append((arg, args[i + 1])) }
        }
        guard !inputs.isEmpty else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let out = docs.appendingPathComponent("debug-runs.json")
        var runs = (try? JSONDecoder().decode([Run].self, from: Data(contentsOf: out))) ?? []
        for (flag, value) in inputs {
            switch flag {
            case "-testDevice":
                guard value.hasPrefix("ios-test-") else { continue }
                UserDefaults.standard.set(value, forKey: "shopper.deviceId")
                model.deviceId = value
            case "-checkLink":
                guard let url = URL(string: value), url.scheme == "https" else { continue }
                let outcome = await ScanPipeline.run(url: url, deviceId: model.deviceId)
                model.remember(outcome)
                runs.append(run(value, outcome))
            default:
                let file = docs.appendingPathComponent((value as NSString).lastPathComponent)
                guard let data = try? Data(contentsOf: file) else { continue }
                try? FileManager.default.removeItem(at: file)
                let outcome = await ScanPipeline.run(imageData: data, deviceId: model.deviceId)
                model.remember(outcome)
                runs.append(run(file.lastPathComponent, outcome))
            }
        }
        try? JSONEncoder().encode(runs).write(to: out)
    }

    static func run(_ input: String, _ o: ScanOutcome) -> Run {
        let e = o.extract
        var fields: [String: String] = [:]
        fields["title"] = e.title
        fields["retailer"] = e.retailer
        fields["currentPrice"] = e.currentPrice.map { String($0) }
        fields["originalPrice"] = e.originalPrice.map { String($0) }
        fields["fallbackLines"] = e.fallbackLines.isEmpty ? nil : String(e.fallbackLines.count)
        return Run(input: input, verdict: o.response?.verdict.rawValue, productId: o.response?.productId,
                   matchedTitle: o.response?.matchedTitle, reason: o.response?.reason, isSampleData: o.response?.isSampleData,
                   reportStatus: o.response?.reportStatus, error: o.error?.message, extract: fields, times: o.times, at: Date())
    }
}
#endif
