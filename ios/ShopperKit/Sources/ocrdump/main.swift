import Foundation
import ShopperKit

// Dev tool: OCR screenshots on this Mac with the same Vision settings as the phone and print fixture JSON.
// Usage: swift run ocrdump <image>...   (images stay local; commit only the JSON lines, never personal screenshots)
@main
struct OCRDump {
    static func main() async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        for path in CommandLine.arguments.dropFirst() {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            guard let image = TextRecognizer.cgImage(from: data) else { throw CocoaError(.fileReadCorruptFile) }
            let start = Date()
            let lines = try await TextRecognizer.recognize(image, accurate: ProcessInfo.processInfo.environment["OCR_ACCURATE"] == "1").map { line in
                OCRLine(text: line.text, x: round4(line.x), y: round4(line.y), w: round4(line.w), h: round4(line.h))
            }
            let ocrSeconds = Date().timeIntervalSince(start)
            let result = ProductExtractor.extract(lines)
            FileHandle.standardError.write(Data("\(path): \(lines.count) lines, OCR \(String(format: "%.3f", ocrSeconds)) s -> \(result)\n".utf8))
            print(String(decoding: try encoder.encode(lines), as: UTF8.self))
        }
    }

    static func round4(_ value: Double) -> Double { (value * 10_000).rounded() / 10_000 }
}
