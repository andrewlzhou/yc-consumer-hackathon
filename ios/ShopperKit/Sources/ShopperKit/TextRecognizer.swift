#if canImport(Vision)
import CoreGraphics
import Foundation
import ImageIO
import Vision

// On-device OCR with Vision. The image stays in memory; nothing is written to disk.
public enum TextRecognizer {
    public static func recognize(_ image: CGImage, accurate: Bool = false) async throws -> [OCRLine] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = accurate ? .accurate : .fast
        request.usesLanguageCorrection = false
        request.minimumTextHeightFraction = 0.008
        let observations = try await request.perform(on: image)
        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = markSuperscriptCents(candidate)
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            let box = observation.boundingBox.cgRect
            return OCRLine(text: text, x: box.minX, y: 1 - box.maxY, w: box.width, h: box.height)
        }
        .sorted { ($0.y, $0.x) < ($1.y, $1.x) }
    }

    // "$27900" read flat from "$279⁰⁰": when the last two digits are clearly smaller or raised, write "$279.00".
    // Without that evidence the text is left as read and PriceText treats long comma-less amounts as ambiguous.
    static func markSuperscriptCents(_ candidate: RecognizedText) -> String {
        var text = candidate.string
        let pattern = try! NSRegularExpression(pattern: #"\$\s?(\d{3,5})(?![\d.,])"#)
        let matches = pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()
        for match in matches {
            guard let digits = Range(match.range(at: 1), in: text) else { continue }
            let centsStart = text.index(digits.upperBound, offsetBy: -2)
            guard let lead = candidate.boundingBox(for: digits.lowerBound..<centsStart)?.boundingBox.cgRect,
                  let cents = candidate.boundingBox(for: centsStart..<digits.upperBound)?.boundingBox.cgRect,
                  lead.height > 0 else { continue }
            let smaller = cents.height < lead.height * 0.8
            let raised = cents.minY > lead.minY + lead.height * 0.2
            if smaller || raised { text.insert(".", at: centsStart) }
        }
        return text
    }

    public static func cgImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
#endif
