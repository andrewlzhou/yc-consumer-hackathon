import Foundation

// A dollar amount found in one OCR line, with what the words around it say about it.
public struct PriceMention: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case plain, original, noise }
    public var value: Double
    public var kind: Kind
    public var line: OCRLine
    public var offset: Int
}

public enum PriceText {
    // "$1,299.99", "$198", "$198.00", "$ 27.99". Amounts without a dollar sign are ignored.
    private static let amount = try! NSRegularExpression(pattern: #"\$\s?(\d{1,3}(?:,\d{3})+|\d{1,6})(?:\.(\d{2}))?(?![\d,]|\.\d)"#)
    private static let range = try! NSRegularExpression(pattern: #"\$\s?[\d,.]+\s?(-|–|—|to)\s?\$\s?[\d,.]+"#)
    private static let originalWords = try! NSRegularExpression(
        pattern: #"\b(was|reg|regular|list|typical|original|orig|compare at|comp\.? value|msrp|before)\b"#)
    private static let lineNoise = try! NSRegularExpression(pattern: #"\b(payments?|interest|apr|affirm|klarna|afterpay|financing|installments?|monthly|shipping|delivery|gift ?card|rewards?|cash ?back|trade.?in|protection|applecare|geek squad|membership|coupon|credit card|other sellers|used|refurbished|renewed|bundle|until cancell?ed|per year|yr)\b"#)
    private static let noiseBefore = try! NSRegularExpression(pattern: #"(\bsave|\bsaving|\bfrom|\bstarting at|\+|\bplan|\bextra|\bget)\W*$"#)
    private static let noiseAfter = try! NSRegularExpression(pattern: #"^\s*(/|[1l|]\s?(mo|yr)\b|off\b|per\b|a month|mo\b|each\b|ea\b|with\b|back\b|credit\b)"#)

    public static func mentions(in line: OCRLine) -> [PriceMention] {
        let text = line.text
        let lower = text.lowercased() as NSString
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        let isLineNoise = range.firstMatch(in: text, range: full) != nil
            || lineNoise.firstMatch(in: lower as String, range: full) != nil
        let matches = amount.matches(in: text, range: full)
        return matches.enumerated().compactMap { index, match in
            let whole = ns.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
            let hasCents = match.range(at: 2).location != NSNotFound
            // Stores always write thousands with a comma, so "$27900" or "$1999" is a price with superscript cents.
            let superscript = !hasCents && !ns.substring(with: match.range(at: 1)).contains(",") && whole.count >= 4
            guard whole.count <= 5 || !superscript else { return nil }
            let dollars = superscript ? String(whole.dropLast(2)) : whole
            let cents = hasCents ? ns.substring(with: match.range(at: 2)) : (superscript ? String(whole.suffix(2)) : "00")
            guard let value = Double(dollars + "." + cents), value > 0, value < 100_000 else { return nil }

            let previousEnd = index > 0 ? matches[index - 1].range.location + matches[index - 1].range.length : 0
            let beforeStart = max(previousEnd, match.range.location - 24)
            let before = lower.substring(with: NSRange(location: beforeStart, length: match.range.location - beforeStart))
            let afterStart = match.range.location + match.range.length
            let after = lower.substring(with: NSRange(location: afterStart, length: min(14, lower.length - afterStart)))
            let isNoise = isLineNoise
                || noiseBefore.firstMatch(in: before, range: NSRange(location: 0, length: (before as NSString).length)) != nil
                || noiseAfter.firstMatch(in: after, range: NSRange(location: 0, length: (after as NSString).length)) != nil
            let isOriginal = originalWords.firstMatch(in: before, range: NSRange(location: 0, length: (before as NSString).length)) != nil
                || (matches.count == 1 && originalWords.firstMatch(in: lower as String, range: full) != nil)
            let kind: PriceMention.Kind = isNoise ? .noise : (isOriginal ? .original : .plain)
            return PriceMention(value: value, kind: kind, line: line, offset: match.range.location)
        }
    }
}
