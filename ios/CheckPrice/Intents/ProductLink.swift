// checkprice://product/<productId> opens that product's thread (ContentView's onOpenURL). It carries only the
// backend's opaque catalog id: never a title, price, screenshot, key or anything about the person.
import Foundation

enum ProductLink {
    static let scheme = "checkprice"

    static func url(productId: String) -> URL? {
        guard isValid(productId) else { return nil }
        return URL(string: "\(scheme)://product/\(productId)")
    }

    static func productId(from url: URL) -> String? {
        guard url.scheme == scheme, url.host() == "product", url.query() == nil, url.fragment() == nil else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 1, isValid(parts[0]) else { return nil }
        return parts[0]
    }

    // Convex ids are short runs of letters and digits; anything else is refused rather than looked up.
    static func isValid(_ id: String) -> Bool {
        (1...64).contains(id.count) && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
    }
}
