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
            let text = observation.topCandidates(1).first?.string ?? ""
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            let box = observation.boundingBox.cgRect
            return OCRLine(text: text, x: box.minX, y: 1 - box.maxY, w: box.width, h: box.height)
        }
        .sorted { ($0.y, $0.x) < ($1.y, $1.x) }
    }

    public static func cgImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
#endif
