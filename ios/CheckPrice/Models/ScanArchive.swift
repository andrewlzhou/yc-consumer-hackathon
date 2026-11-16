// Real checks and where they are kept on this phone. A check made from a Shortcut runs while the app is in the
// background and iOS may close the app right after, so each one is saved: it is still in Threads, and its Details
// button still finds it, after a restart. Saved: the product's title and id and what the check was told. Never the
// screenshot or other text from the screen.
import Foundation

// What one real check saw and was told. It never changes: a report adds history around it, and only an analysis
// made for the same price may refine its verdict (Backend/ReportFigures.swift).
struct CheckSnapshot: Codable, Equatable {
    // The price read off the screen; nil for a link.
    var price: Double?
    // The store as the phone read it; empty when unknown.
    var retailer: String
    var verdict: Verdict
    var reason: String
    var isSampleData: Bool
}

extension Verdict: Codable {}

extension Product {
    // A checked product as its check left it, before any report.
    init(name: String, productId: String?, check: CheckSnapshot) {
        self.init(name: name, retailer: check.retailer, price: check.price.map(Money.text) ?? "", icon: "tag", verdict: check.verdict,
                  summary: check.reason, projectedLow: "", productId: productId, isSampleData: check.isSampleData, check: check)
    }
}

struct ScanArchive {
    let file: URL

    static let standard = ScanArchive(file: URL.applicationSupportDirectory.appending(path: "checks.json"))

    private struct Entry: Codable {
        var id: UUID
        var startedAt: Date
        var name: String
        var productId: String?
        var check: CheckSnapshot
    }

    // Newest first, as ThreadStore keeps them.
    func load() -> [ShoppingThread] {
        guard let data = try? Data(contentsOf: file), let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries.map {
            ShoppingThread(id: $0.id, product: Product(name: $0.name, productId: $0.productId, check: $0.check), startedAt: $0.startedAt,
                           isSaved: false, messages: [])
        }
    }

    // The 50 newest real checks; demo threads are never saved.
    func save(_ threads: [ShoppingThread]) {
        let entries = threads.compactMap { thread in
            thread.product.check.map { Entry(id: thread.id, startedAt: thread.startedAt, name: thread.product.name, productId: thread.product.productId, check: $0) }
        }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(Array(entries.prefix(50))).write(to: file, options: .atomic)
    }
}
