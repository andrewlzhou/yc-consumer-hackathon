// What the compact result after Back Tap says: one word per backend verdict and a very short reason.
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

enum ShortReason {
    // About two lines in the popup.
    static let maxCharacters = 64

    // The backend's reason cut to its first sentence, then, if still long, to the last clause that fits
    // ("At $198, these headphones match their recorded low and beat…" -> "At $198, these headphones match
    // their recorded low"). Clauses are cut whole so no number loses what it refers to; only a reason with
    // no clause break that fits gets an ellipsis.
    static func make(_ reason: String) -> String {
        var text = firstSentence(reason.trimmingCharacters(in: .whitespacesAndNewlines))
        if text.hasSuffix(".") { text.removeLast() }
        guard text.count > maxCharacters else { return text }

        let window = String(text.prefix(maxCharacters))
        let breaks = [", ", "; ", " — ", " - ", " and ", " but ", " while "]
        let cut = breaks.compactMap { window.range(of: $0, options: .backwards)?.lowerBound }
            .map { window.distance(from: window.startIndex, to: $0) }
            .filter { $0 >= maxCharacters / 3 }
            .max()
        if let cut { return String(text.prefix(cut)) }

        let words = window.split(separator: " ").dropLast()
        return words.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ",;:—-")) + "…"
    }

    // Up to the first ". ", "! " or "? "; a decimal point like "$198.99" has no space after it.
    private static func firstSentence(_ text: String) -> String {
        let ends = [". ", "! ", "? "].compactMap { text.range(of: $0)?.lowerBound }
        guard let end = ends.min() else { return text }
        return String(text[...end])
    }
}
