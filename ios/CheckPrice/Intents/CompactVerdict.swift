// What the compact result after Back Tap says: the decision, one word per backend verdict.
import Foundation

extension Verdict {
    // Ruhaan, 2026-11-15 (CON-12, option C): four labels, one per backend verdict, never merged.
    var compactLabel: String {
        switch self {
        case .buyNow: "BUY"
        case .wait: "WAIT"
        case .alternative: "LOOK ELSEWHERE"
        case .investigate: "INDETERMINATE"
        }
    }

    // VoiceOver reads this instead of the capitals.
    var compactSpokenLabel: String { compactLabel.capitalized }
}
