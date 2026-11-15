// Target membership: BOTH the app and the widget extension.
// The X button on the "Digging…" pop-up.
import AppIntents
import ActivityKit

struct CancelScanIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Cancel price check"

    func perform() async throws -> some IntentResult {
        for activity in Activity<ScanAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}
