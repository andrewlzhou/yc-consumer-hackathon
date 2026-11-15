import Foundation
import ShopperKit
#if canImport(FoundationModels)
import FoundationModels
#endif

// Optional on-device language model for screens the rules could not read. Only used when Apple Intelligence is
// available; its answer is kept only if the title is on screen and the price is one the rules also parsed.
enum ModelAssist {
    static var availability: String {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available: return "available"
        case let .unavailable(reason): return "unavailable (\(reason))"
        }
        #else
        return "not in this SDK"
        #endif
    }

    static func refine(lines: [OCRLine], current: ExtractionResult) async -> ExtractionResult? {
        #if canImport(FoundationModels)
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let text = lines.prefix(40).map(\.text).joined(separator: "\n")
        let session = LanguageModelSession(instructions: "You read OCR text from a phone screenshot of a shopping app. Copy the product title exactly as written and the price the shopper pays now. Leave a field empty when unsure.")
        do {
            let guess = try await session.respond(to: text, generating: ProductGuess.self).content
            var refined = current
            let screen = text.lowercased()
            if refined.title == nil, let title = guess.title, title.count >= 6, screen.contains(title.lowercased()) {
                refined.title = title
                refined.fallbackLines = []
            }
            let seen = Set(lines.flatMap(PriceText.mentions(in:)).filter { $0.kind != .noise }.map(\.value))
            if refined.currentPrice == nil, let price = guess.currentPrice, seen.contains(price) {
                refined.currentPrice = price
            }
            return refined == current ? nil : refined
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}

#if canImport(FoundationModels)
@Generable
struct ProductGuess {
    @Guide(description: "Product title copied exactly from the text, or empty")
    var title: String?
    @Guide(description: "Price in US dollars the shopper pays now, or empty")
    var currentPrice: Double?
}
#endif
