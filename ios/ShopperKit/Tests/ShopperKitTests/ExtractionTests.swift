import Foundation
import Testing
@testable import ShopperKit

struct Fixture: Decodable {
    struct Expected: Decodable {
        var titleContains: [String]?
        var retailer: String?
        var currentPrice: Double?
        var originalPrice: Double?
        var product: Bool
        var knownMiss: [String]?
    }
    var name: String
    var expected: Expected
    var lines: [OCRLine]

    static func all() throws -> [Fixture] {
        let dir = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!
        return try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: $0)) }
    }
}

enum Outcome: String { case correct, blank, wrong }

func grade(_ fixture: Fixture, _ result: ExtractionResult) -> [String: Outcome] {
    let e = fixture.expected
    func field<T: Equatable>(_ got: T?, _ want: T?) -> Outcome {
        got == want ? .correct : (got == nil ? .blank : .wrong)
    }
    let title: Outcome = {
        guard let want = e.titleContains else { return result.title == nil ? .correct : .wrong }
        guard let got = result.title else { return .blank }
        return want.allSatisfy(got.contains) ? .correct : .wrong
    }()
    return [
        "title": title,
        "retailer": field(result.retailer, e.retailer),
        "currentPrice": field(result.currentPrice, e.currentPrice),
        "originalPrice": field(result.originalPrice, e.originalPrice),
        "product": result.hasProduct == e.product ? .correct : .wrong,
    ]
}

@Test func fixturesExtractAsExpected() throws {
    var tally: [String: [Outcome: Int]] = [:]
    for fixture in try Fixture.all() {
        let grades = grade(fixture, ProductExtractor.extract(fixture.lines))
        for (field, outcome) in grades {
            tally[field, default: [:]][outcome, default: 0] += 1
            let known = fixture.expected.knownMiss?.contains(field) ?? false
            #expect(outcome == .correct || known, "\(fixture.name) \(field): \(outcome)")
        }
    }
    for field in tally.keys.sorted() {
        let t = tally[field]!
        print("accuracy \(field): correct \(t[.correct] ?? 0), blank \(t[.blank] ?? 0), wrong \(t[.wrong] ?? 0)")
    }
}

@Test func neverInventsAPriceWhenNoneIsShown() throws {
    let lines = [OCRLine(text: "Sony WH-1000XM5 Wireless Headphones Black", x: 0.05, y: 0.5, w: 0.8, h: 0.02)]
    let result = ProductExtractor.extract(lines)
    #expect(result.currentPrice == nil && result.originalPrice == nil)
    #expect(result.title == "Sony WH-1000XM5 Wireless Headphones Black")
}

@Test func priceParsingHandlesStoreFormats() {
    func values(_ text: String) -> [Double] { PriceText.mentions(in: OCRLine(text: text, x: 0, y: 0.5, w: 1, h: 0.02)).map(\.value) }
    #expect(values("$1,299.99") == [1299.99])
    #expect(values("$279.00 List: $35") == [279.0, 35.0])
    #expect(values("$27900").isEmpty)
    #expect(values("$1099").isEmpty)
    #expect(values("C$349.99").isEmpty)
    #expect(values("$1.991mo. or $19.99/yr.").isEmpty == false)
    #expect(values("$2.299.99").isEmpty)
    #expect(values("$123456").isEmpty)
    func kinds(_ text: String) -> [PriceMention.Kind] { PriceText.mentions(in: OCRLine(text: text, x: 0, y: 0.5, w: 1, h: 0.02)).map(\.kind) }
    #expect(kinds("Was $399.99 Now $279.99") == [.original, .plain])
    #expect(kinds("$23.33/mo. for 12 months") == [.noise])
    #expect(kinds("-43% $198.00") == [.plain])
    #expect(kinds("Save $120") == [.noise])
    #expect(kinds("$19.99 - $29.99") == [.noise, .noise])
    #expect(kinds("Coupon -$50.00") == [.noise])
    #expect(kinds("2 for $5.00") == [.noise])
    #expect(kinds("Subtotal $329.98") == [.noise])
}
