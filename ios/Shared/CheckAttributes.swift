// Target membership: BOTH the app and the widget extension (project.yml lists Shared/ in each).
// The check's pop-up (Live Activity / Dynamic Island) has two stages: `checking`, then `decided`
// with a verdict and a very short reason. There is no "don't buy" verdict, by owner rule.
import ActivityKit
import Foundation

struct CheckAttributes: ActivityAttributes {
    enum Stage: String, Codable, Hashable { case checking, decided }

    struct ContentState: Codable, Hashable {
        var stage: Stage
        var verdict: IslandVerdict? = nil
        // A very short why (about 8 words at most), shown only once decided.
        var reason: String? = nil
        // Live Activities can't loop animations, so each update moves the wisps to a new pose
        // and iOS animates between poses. The app bumps this a few times while checking.
        var phase: Int = 0
    }
}

// Same raw values as the app's `Verdict` (CheckPrice/Models/Demo.swift); the widget can't see
// CheckPrice/. The words are the pop-up's own, not `Verdict.word`.
enum IslandVerdict: String, Codable, Hashable {
    case buyNow = "BUY NOW"
    case wait = "WAIT"
    case alternative = "CONSIDER ALTERNATIVE"
    case investigate = "INVESTIGATE"

    var word: String {
        switch self {
        case .buyNow: "Buy Now"
        case .wait: "Buy Later"
        case .alternative: "Look Around"
        case .investigate: "Check First"
        }
    }
}
