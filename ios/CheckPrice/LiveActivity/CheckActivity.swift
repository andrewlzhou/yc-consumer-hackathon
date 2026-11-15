// Starts and updates the check's pop-up (Live Activity / Dynamic Island). The views are in
// ios/Widget/, the shared state in ios/Shared/CheckAttributes.swift.
//
// Demo for simulators and cloud devices: launch with `-demoLiveActivity YES` (optionally
// `-demoVerdict wait|buy|alternative|investigate`, default wait). It shows a playful checking
// word (a new one each update, from `CheckingWords`) with the wisps moving every 1.5 seconds,
// then the verdict at 6 seconds. iOS hides an app's own pop-up while that app is open, so swipe
// home right after launch to see the Dynamic Island.
import ActivityKit
import UIKit

@MainActor
enum CheckActivity {
    // Checking for `duration` seconds in four wisp poses, then the verdict with an alert, which
    // expands the island and lights the Lock Screen.
    static func play(verdict: Verdict, reason: String, over duration: TimeInterval) async {
        // Keep going after the user swipes home, or the verdict waits for the next launch.
        let task = UIApplication.shared.beginBackgroundTask(withName: "checkActivity")
        defer { UIApplication.shared.endBackgroundTask(task) }

        guard let activity = await start() else { return }
        let step = duration / 4
        let wordStart = activity.content.state.wordStart
        for phase in 1...3 {
            try? await Task.sleep(for: .seconds(step))
            await activity.update(ActivityContent(
                state: .init(stage: .checking, phase: phase, wordStart: wordStart), staleDate: nil))
        }
        try? await Task.sleep(for: .seconds(step))
        await decide(activity, verdict: verdict, reason: reason, phase: 4)
    }

    // Ends any earlier pop-up (starting a second one can fail), then starts one in `checking`.
    static func start() async -> Activity<CheckAttributes>? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
        for old in Activity<CheckAttributes>.activities {
            await old.end(nil, dismissalPolicy: .immediate)
        }
        return try? Activity<CheckAttributes>.request(
            attributes: CheckAttributes(),
            content: ActivityContent(
                state: .init(stage: .checking, wordStart: Int.random(in: 0..<CheckingWords.all.count)),
                staleDate: nil),
            pushType: nil)
    }

    static func decide(_ activity: Activity<CheckAttributes>, verdict: Verdict, reason: String, phase: Int) async {
        guard let islandVerdict = IslandVerdict(rawValue: verdict.rawValue) else { return }
        let state = CheckAttributes.ContentState(stage: .decided, verdict: islandVerdict, reason: reason, phase: phase)
        await activity.update(
            ActivityContent(state: state, staleDate: nil),
            alertConfiguration: AlertConfiguration(
                title: LocalizedStringResource(stringLiteral: islandVerdict.word),
                body: LocalizedStringResource(stringLiteral: reason),
                sound: .default))
    }

    static func runDemoIfRequested() async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "demoLiveActivity") else { return }
        let (verdict, reason) = demoVerdict(defaults.string(forKey: "demoVerdict") ?? "wait")
        await play(verdict: verdict, reason: reason, over: 6)
    }

    // A few words each.
    private static func demoVerdict(_ key: String) -> (Verdict, String) {
        switch key.lowercased() {
        case "buy": (.buyNow, "Near its lowest price")
        case "alternative": (.alternative, "A similar model costs less")
        case "investigate": (.investigate, "Little price history yet")
        default: (.wait, "~$40 less by Cyber Monday")
        }
    }
}
