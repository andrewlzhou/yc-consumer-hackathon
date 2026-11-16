// Target membership: BOTH the app and the widget extension (project.yml lists Shared/ in each).
// The check's pop-up (Live Activity / Dynamic Island) has two stages: `checking` (a rotating
// playful word from `CheckingWords`), then `decided`
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
        // Where the checking word starts in `CheckingWords.all`, picked at random when the check
        // begins; each update then shows the next word (`wordStart + phase`).
        var wordStart: Int = 0
    }
}

// The playful words shown while checking, one per update. Edit the list here; nothing else
// depends on its length or order.
enum CheckingWords {
    static let all = [
        "Cogitating", "Haggling", "Bargainating", "Pricesplaining", "Dealsleuthing",
        "Couponjuring", "Markdownmusing", "Rizzazomating", "Thriftulating", "Splurgevading",
    ]

    static func word(start: Int, phase: Int) -> String {
        let n = all.count
        return all[((start + phase) % n + n) % n]
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
