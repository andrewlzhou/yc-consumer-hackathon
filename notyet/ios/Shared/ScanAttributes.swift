// Target membership: BOTH the app and the widget extension.
import ActivityKit
import Foundation

struct ScanAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stage: String          // "working" | "ready" | "failed"
        var headline: String       // progress text, then the one-liner verdict
        var productName: String?
        var verdict: String?       // "BUY_NOW" | "WAIT" | "FAKE_DEAL" | "CONSIDER_ALTERNATIVE" | "INVESTIGATE"; the widget shows unknown values as "Ready"
        var scanKey: String
        var etaEnd: Date           // drives the self-animating progress bar
        var retailer: String? = nil
    }
    var startedAt: Date
}
