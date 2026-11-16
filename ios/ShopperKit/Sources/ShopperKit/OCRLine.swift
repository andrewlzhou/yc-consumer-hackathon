import Foundation

// One recognized line of screen text. Box is normalized to the image with a top-left origin.
public struct OCRLine: Codable, Equatable, Sendable {
    public var text: String
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    public init(text: String, x: Double, y: Double, w: Double, h: Double) {
        self.text = text
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    public var midY: Double { y + h / 2 }
    public var bottom: Double { y + h }
}
