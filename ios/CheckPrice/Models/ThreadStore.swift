// Threads: one per time the app was triggered while shopping. Shared contract for Home, Threads,
// the thread detail, and Account. Chat replies are canned until a chat backend exists. Checked
// products fetch their report and sync Save with the backend watchlist.
import SwiftUI
import Observation
import ShopperKit

struct ChatMessage: Identifiable, Hashable {
    let id: UUID
    let fromUser: Bool
    let text: String
    let sentAt: Date

    init(id: UUID = UUID(), fromUser: Bool, text: String, sentAt: Date = .now) {
        self.id = id
        self.fromUser = fromUser
        self.text = text
        self.sentAt = sentAt
    }
}

struct ShoppingThread: Identifiable {
    let id: UUID
    var product: Product
    let startedAt: Date
    var isSaved: Bool
    var messages: [ChatMessage]
    // GET /report for checked products; nil for demo threads and until it arrives.
    var report: ReportResponse? = nil
}

@MainActor @Observable
final class ThreadStore {
    // Newest first.
    var threads: [ShoppingThread]
    // Set to open a thread's detail as a sheet from anywhere (ContentView presents it).
    var openThreadID: UUID?
    // The id of the reply currently being "typed", so the detail view can stream it.
    var replyingIn: UUID?
    // GET /report; tests swap it for a stub.
    @ObservationIgnored var fetchReport: (String) async throws -> ReportResponse = { try await Backend.client.report(productId: $0) }
    // Where real checks are kept across restarts; nil in tests and previews.
    @ObservationIgnored private let archive: ScanArchive?
    // The report load now running for each thread. A newer load takes a thread over; the older one stops.
    @ObservationIgnored private var reportLoads: [UUID: Int] = [:]
    @ObservationIgnored private var lastLoad = 0

    static let shared = ThreadStore(threads: ScanArchive.standard.load() + DemoThreads.all, archive: .standard)

    init(threads: [ShoppingThread] = DemoThreads.all, archive: ScanArchive? = nil) {
        self.threads = threads
        self.archive = archive
    }

    var saved: [ShoppingThread] { threads.filter(\.isSaved) }

    func thread(_ id: UUID) -> ShoppingThread? { threads.first { $0.id == id } }

    @discardableResult
    func startThread(for product: Product) -> UUID {
        let thread = ShoppingThread(id: UUID(), product: product, startedAt: .now, isSaved: false, messages: [])
        threads.insert(thread, at: 0)
        if product.check != nil { archive?.save(threads) }
        return thread.id
    }

    // Save is the backend watchlist for checked products; it flips back if the backend refuses.
    func toggleSave(_ id: UUID) {
        update(id) { $0.isSaved.toggle() }
        guard let thread = thread(id), let productId = thread.product.productId else { return }
        let saved = thread.isSaved
        Task { @MainActor in
            do {
                if saved { try await Backend.client.save(productId: productId) }
                else { try await Backend.client.remove(productId: productId) }
            } catch {
                update(id) { $0.isSaved = !saved }
            }
        }
    }

    // Fetches a checked product's report, then again every few seconds while the full analysis is still running.
    // Only this thread's own product's report is kept, and only from the newest load.
    func loadReport(for id: UUID) {
        guard let product = thread(id)?.product, product.check != nil, let productId = product.productId else { return }
        lastLoad += 1
        let load = lastLoad
        reportLoads[id] = load
        Task { @MainActor in
            defer { if reportLoads[id] == load { reportLoads[id] = nil } }
            for attempt in 0..<6 {
                if attempt > 0 { try? await Task.sleep(for: .seconds(3)) }
                guard reportLoads[id] == load else { return }
                let report = try? await fetchReport(productId)
                guard reportLoads[id] == load else { return }
                guard let report, report.product.productId == productId else { continue }
                update(id) {
                    $0.report = report
                    $0.product = $0.product.updated(with: report)
                }
                if !report.pending { return }
            }
        }
    }

    // For a thread opened later (from Threads, or kept from before a restart): fetches the report unless the
    // thread has its finished one or a load is already running.
    func loadReportIfNeeded(for id: UUID) {
        guard reportLoads[id] == nil, thread(id)?.report?.pending ?? true else { return }
        loadReport(for: id)
    }

    // Opens one saved check by its own id: the Back Tap result's More Details lands here. False when the phone
    // no longer has that check; the app is in front either way.
    @discardableResult
    func openCheck(_ checkId: String) -> Bool {
        guard let id = UUID(uuidString: checkId), thread(id)?.product.check != nil else { return false }
        openThreadID = id
        loadReportIfNeeded(for: id)
        return true
    }

    // Opens the newest check of a backend product: checkprice://product/<id> lands here. Checks are kept across restarts (ScanArchive), so the thread is the
    // check itself, with its own price and verdict. A product never checked on this phone opens nothing.
    func openProduct(_ productId: String) {
        guard let id = threads.first(where: { $0.product.check != nil && $0.product.productId == productId })?.id else { return }
        openThreadID = id
        loadReportIfNeeded(for: id)
    }

    // Appends the user's message, then a canned reply after a short pause.
    func send(_ text: String, in id: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let product = thread(id)?.product else { return }
        update(id) { $0.messages.append(ChatMessage(fromUser: true, text: trimmed)) }
        replyingIn = id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            update(id) { $0.messages.append(ChatMessage(fromUser: false, text: DemoThreads.reply(to: trimmed, about: product))) }
            if replyingIn == id { replyingIn = nil }
        }
    }

    private func update(_ id: UUID, _ change: (inout ShoppingThread) -> Void) {
        guard let i = threads.firstIndex(where: { $0.id == id }) else { return }
        change(&threads[i])
    }
}

enum DemoThreads {
    static let all: [ShoppingThread] = {
        let products = Demo.saved
        let now = Date.now
        return [
            ShoppingThread(id: UUID(), product: Demo.headphones, startedAt: now.addingTimeInterval(-3_600), isSaved: true,
                           messages: [ChatMessage(fromUser: true, text: "Is Cyber Monday really cheaper?", sentAt: now.addingTimeInterval(-3_500)),
                                      ChatMessage(fromUser: false, text: "It dropped about $40 during the last two November sales.", sentAt: now.addingTimeInterval(-3_480))]),
            // Saved so Home's Watchlist has an item whose (sample) price dropped recently.
            ShoppingThread(id: UUID(), product: products[0], startedAt: now.addingTimeInterval(-86_400 * 2), isSaved: true, messages: []),
            ShoppingThread(id: UUID(), product: products[1], startedAt: now.addingTimeInterval(-86_400 * 9), isSaved: true, messages: []),
        ]
    }()

    static func reply(to question: String, about product: Product) -> String {
        "For the \(product.name), the best price we expect is \(product.projectedLow). \(product.summary)"
    }
}
