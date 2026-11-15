// Target membership: app only.
// Shows the scan pop-up (Live Activity / Dynamic Island) with no Shortcut, for simulators.
// Launch with `-demoLiveActivity YES`; mock mode only. "Digging…" walks through the steps for
// 6 seconds, then the verdict of sample key `-demoVerdict <key>` (default "a", the Wait sample).
// The Dynamic Island only shows it while the app is in the background, so swipe home after launch.
import ActivityKit
import UIKit

enum DemoLiveActivity {
    static let duration: TimeInterval = 6

    @MainActor
    static func runIfRequested() async {
        let defaults = UserDefaults.standard
        guard ScanAPI.useMocks, defaults.bool(forKey: "demoLiveActivity") else { return }
        let sampleKey = defaults.string(forKey: "demoVerdict") ?? "a"

        // Keep counting after the tester swipes home, or the switch to "ready" waits for the next launch.
        let task = UIApplication.shared.beginBackgroundTask(withName: "demoLiveActivity")
        defer { UIApplication.shared.endBackgroundTask(task) }

        let scanKey = sampleKey
        let steps = DigStage.allCases.map { $0.label + "…" }
        guard let activity = await ScanActivity.start(scanKey: scanKey, duration: duration, headline: steps[0])
        else { return }

        let stepTime = duration / Double(steps.count)
        for step in steps.dropFirst() {
            try? await Task.sleep(for: .seconds(stepTime))
            var state = activity.content.state
            state.headline = step
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
        try? await Task.sleep(for: .seconds(stepTime))

        let r = SampleData.result(for: sampleKey)
        let quick = ScanAPI.Quick(scanKey: scanKey, productName: r.product.name, verdict: r.verdict,
                                  oneLiner: r.oneLiner, retailer: r.whereToBuy?.retailer)
        await ScanActivity.showReady(activity, quick: quick, scanKey: scanKey)
    }
}
