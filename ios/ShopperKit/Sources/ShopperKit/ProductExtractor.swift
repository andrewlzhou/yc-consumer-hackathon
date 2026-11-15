import Foundation

// What the phone could read off one screenshot. Blank beats wrong: every field is left nil unless the rules agree.
public struct ExtractionResult: Equatable, Sendable {
    public var title: String?
    public var retailer: String?
    public var currentPrice: Double?
    public var originalPrice: Double?
    public var isListing = false
    // A few pruned lines for the backend, only when the title could not be read.
    public var fallbackLines: [String] = []

    public init() {}

    public var hasProduct: Bool { !isListing && (title != nil || (currentPrice != nil && !fallbackLines.isEmpty)) }
}

public enum ProductExtractor {
    public static func extract(_ allLines: [OCRLine]) -> ExtractionResult {
        let lines = allLines.filter { $0.y > 0.045 }.sorted { ($0.y, $0.x) < ($1.y, $1.x) }
        var result = ExtractionResult()
        result.retailer = retailer(in: allLines)

        let mentions = lines.flatMap(PriceText.mentions(in:))
        let plain = mentions.filter { $0.kind == .plain }
        if isListingGrid(plain) {
            result.isListing = true
            return result
        }
        let current = currentPrice(plain)
        result.currentPrice = current?.value
        if let current {
            result.originalPrice = originalPrice(for: current, mentions: mentions)
        }
        result.title = title(in: lines, near: current?.line)
        if result.title == nil, current != nil {
            result.fallbackLines = Array(titleCandidates(lines).sorted { $0.h > $1.h }.prefix(12).map { String($0.text.prefix(200)) })
        }
        return result
    }

    // Search results and carousels: the biggest price shares its row with another, or many prices are all the same size.
    static func isListingGrid(_ plain: [PriceMention]) -> Bool {
        guard let tallest = plain.max(by: { $0.line.h < $1.line.h }) else { return false }
        let rowmates = plain.filter {
            $0.line != tallest.line && abs($0.line.midY - tallest.line.midY) < tallest.line.h * 0.6
                && abs($0.line.x - tallest.line.x) > 0.2 && $0.line.h >= tallest.line.h * 0.9
        }
        if !rowmates.isEmpty { return true }
        let distinctLines = Dictionary(grouping: plain, by: { Int(($0.line.y * 200).rounded()) }).count
        guard distinctLines >= 4 else { return false }
        let heights = plain.map(\.line.h).sorted()
        return tallest.line.h < heights[heights.count / 2] * 1.35
    }

    // The biggest plain price on screen; ties go to the higher one.
    static func currentPrice(_ plain: [PriceMention]) -> PriceMention? {
        guard let tallest = plain.map(\.line.h).max() else { return nil }
        let top = plain.filter { $0.line.h >= tallest * 0.95 }.sorted { ($0.line.y, $0.offset) < ($1.line.y, $1.offset) }
        let values = Set(top.map(\.value))
        if values.count > 1 && top.count > 2 { return nil }
        return top.first
    }

    // A labelled "was/reg/list" price near the current one, else one unlabelled higher, smaller price right beside it.
    static func originalPrice(for current: PriceMention, mentions: [PriceMention]) -> Double? {
        let reach = max(current.line.h * 3, 0.06)
        let plausible = mentions.filter {
            $0 != current && $0.value > current.value * 1.01 && $0.value <= current.value * 5
                && abs($0.line.midY - current.line.midY) <= reach
        }
        let labelled = plausible.filter { $0.kind == .original }
        if let nearest = labelled.min(by: { abs($0.line.midY - current.line.midY) < abs($1.line.midY - current.line.midY) }) {
            return nearest.value
        }
        let beside = plausible.filter {
            $0.kind == .plain && $0.line.h < current.line.h * 0.95 && abs($0.line.midY - current.line.midY) <= max(current.line.h * 1.6, 0.03)
        }
        let sameLine = plausible.filter { $0.kind == .plain && $0.line == current.line && $0.offset > current.offset }
        let candidates = sameLine.isEmpty ? beside : sameLine
        return Set(candidates.map(\.value)).count == 1 ? candidates.first?.value : nil
    }

    private static let uiPhrases: [String] = [
        "add to", "buy now", "buy it", "ship", "pickup", "pick up", "delivery", "free ", "in stock", "out of stock", "sold by",
        "see all", "see more", "shop ", "search", "cart", "sign in", "review", "rating", "stars", "sponsored", "save",
        "color", "size", "qty", "quantity", "return", "warranty", "protection", "compare", "sort", "filter", "results",
        "deals", "menu", "account", "price", "was ", "reg ", "list ", "typical", "financing", "payments", "apple pay",
        "choose", "select", "options", "details", "specifications", "overview", "about this", "description", "features",
        "questions", "share", "wish", "favorite", "registry", "store", "aisle", "available", "arrives", "get it", "order",
        "checkout", "prime", "coupon", "membership", "visit the", "brand", "model", "sku", "learn more", "limited time",
        "deal", "only", "left", "bestseller", "best seller", "choice", "new", "sale", "clearance", "online only", "sold out",
        "back", "done", "close", "cancel", "home", "categories", "ships", "location", "zip", "nearby", "join", "member",
    ]
    // Phrases that disqualify a line wherever they appear: delivery, stock, coverage and bot-check text.
    private static let uiFragments: [String] = [
        "deliver", "bought in", "in stock", "learn more", "sign in", "add to", "sold by", "coverage", "verification",
        "robot", "human", "press & hold", "captcha", "access denied", "security", "you might also like", "no longer available",
        "consider these", "% off", "free shipping", "free returns", "rewards", "ratings", "reviews", "personalize", "engrav",
        "used -", "personal information", "privacy", "terms of use", "cookie", "inc.", "rights reserved", "hold the button",
    ]

    static func titleCandidates(_ lines: [OCRLine]) -> [OCRLine] {
        lines.filter { line in
            let text = line.text.trimmingCharacters(in: .whitespaces)
            let lower = text.lowercased()
            let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
            guard text.count >= 4, letters >= 4, Double(letters) / Double(text.count) >= 0.5 else { return false }
            guard !text.contains("$"), !lower.contains(".com"), !lower.contains("www.") else { return false }
            if uiFragments.contains(where: lower.contains) { return false }
            return !uiPhrases.contains { lower.hasPrefix($0) || lower == $0.trimmingCharacters(in: .whitespaces) }
        }
    }

    // Groups wrapped title lines, then prefers big, long text close to (ideally just above) the price.
    static func title(in lines: [OCRLine], near price: OCRLine?) -> String? {
        let candidates = titleCandidates(lines)
        guard let tallest = candidates.map(\.h).max() else { return nil }
        let medianHeight = candidates.map(\.h).sorted()[candidates.count / 2]
        var blocks: [[OCRLine]] = []
        for line in candidates {
            if let last = blocks.last?.last,
               abs(line.h - last.h) <= max(line.h, last.h) * 0.25,
               abs(line.x - last.x) <= 0.04,
               line.y - last.bottom <= max(line.h, last.h) * 1.1,
               line.y >= last.y {
                blocks[blocks.count - 1].append(line)
            } else {
                blocks.append([line])
            }
        }
        let scored = blocks.compactMap { block -> (String, Double)? in
            let text = block.map { $0.text.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
            let words = text.split(separator: " ").count
            guard words >= 3 || text.count >= 15, text.count <= 240 else { return nil }
            let height = block.map(\.h).reduce(0, +) / Double(block.count)
            // With no price on screen only headline-sized text counts as a title.
            if price == nil && candidates.count >= 3 && height < medianHeight * 1.25 { return nil }
            var score = height / tallest + min(Double(text.count), 80) / 80 * 0.8
            if let price {
                let first = block.first!, lastLine = block.last!
                let distance = price.y >= lastLine.bottom ? price.y - lastLine.bottom : abs(first.midY - price.midY)
                score += max(0, 1 - distance / 0.35) + (price.y >= lastLine.bottom ? 0.2 : 0)
            }
            return (text, score)
        }
        guard let best = scored.max(by: { $0.1 < $1.1 }), best.1 >= 1.1 else { return nil }
        return best.0
    }

    private static let domains: [(String, String)] = [
        ("bestbuy.com", "Best Buy"), ("walmart.com", "Walmart"), ("target.com", "Target"), ("amazon.com", "Amazon"),
        ("apple.com", "Apple"), ("nike.com", "Nike"), ("ae.com", "American Eagle"), ("lululemon.com", "lululemon"),
        ("costco.com", "Costco"), ("homedepot.com", "Home Depot"), ("adidas.com", "adidas"), ("newegg.com", "Newegg"),
        ("bhphotovideo.com", "B&H"), ("macys.com", "Macy's"), ("kohls.com", "Kohl's"),
    ]
    private static let storeNames: [(String, String)] = [
        ("best buy", "Best Buy"), ("walmart", "Walmart"), ("target", "Target"), ("amazon", "Amazon"),
        ("american eagle", "American Eagle"), ("lululemon", "lululemon"), ("costco", "Costco"), ("home depot", "Home Depot"),
    ]

    // A store domain anywhere on screen (Safari's address bar) wins; otherwise a store name that is not also a brand.
    static func retailer(in lines: [OCRLine]) -> String? {
        let text = lines.map { $0.text.lowercased() }.joined(separator: "\n")
        for (domain, name) in domains where text.range(of: #"(^|[^a-z0-9])"# + NSRegularExpression.escapedPattern(for: domain), options: .regularExpression) != nil {
            return name
        }
        for (word, name) in storeNames where text.range(of: #"\b"# + word + #"\b"#, options: .regularExpression) != nil {
            if word == "target" && text.range(of: #"target (price|date|audience)"#, options: .regularExpression) != nil { continue }
            return name
        }
        return nil
    }
}
