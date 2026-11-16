// Shortcut actions. Back Tap runs a shortcut: Take Screenshot, then "Scan Screen with Check Price" (named apart from the Worth It
// test app's "Check Price in Screenshot", so the two can't be mixed up in Shortcuts). The check runs in
// the background so the store app stays in front, and iOS shows the compact result (CompactVerdictView) as a
// snippet. Tapping it (More Details) runs OpenProductIntent, which brings Check Price forward on that product's thread.
// The system's own Done button and the platter around the snippet are drawn by iOS and can't be changed.
// A failed check, or a build with no backend key, shows the failure: never a demo verdict.
// iOS 26+: interactive snippets (SnippetIntent) and supportedModes are new there.
import AppIntents
import Foundation
import ShopperKit

@available(iOS 26.0, *)
struct CheckScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan Screen with Check Price"
    static let description = IntentDescription("Reads the product on screen on this iPhone and says whether to buy it now. The screenshot never leaves the phone.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Screenshot", supportedContentTypes: [.image])
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult & ShowsSnippetIntent {
        let start = Date()
        let times = CheckRunner.Times()
        let (bytes, handoff) = ScreenshotFile.readOnce(screenshot)
        let result = await CheckRunner.run(imageData: bytes, times: times)
        ScanDiagnostics.record(source: "screenshot", result: result, handoff: handoff, times: times, since: start)
        return .result(snippetIntent: await VerdictSnippetIntent.record(result))
    }
}

@available(iOS 26.0, *)
struct CheckLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Price of Link"
    static let description = IntentDescription("Says whether the product at this store link is worth buying now.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Link")
    var url: URL

    func perform() async throws -> some IntentResult & ShowsSnippetIntent {
        let start = Date()
        let times = CheckRunner.Times()
        let result = await CheckRunner.run(url: url, times: times)
        ScanDiagnostics.record(source: "link", result: result, handoff: nil, times: times, since: start)
        return .result(snippetIntent: await VerdictSnippetIntent.record(result))
    }
}

// The snippet. Its parameters are the little the popup shows; iOS may run it again when More Details is
// tapped, so it has no side effects.
@available(iOS 26.0, *)
struct VerdictSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Price Verdict"

    // Verdict's raw value; nil when the check failed, and then `failure` says why.
    @Parameter(title: "Verdict") var verdict: String?
    @Parameter(title: "Failure") var failure: String?
    @Parameter(title: "Sample data", default: false) var isSampleData: Bool
    @Parameter(title: "Product") var productId: String?

    init() {}

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: CompactVerdictView(verdict: verdict.flatMap(Verdict.init(rawValue:)), failure: failure,
                                         isSampleData: isSampleData, productId: productId))
    }

    // Keeps a successful check as a new thread (fetching its report), then builds the snippet. A failure makes
    // no thread and has no verdict or More Details button; neither does a check the backend couldn't match.
    @MainActor
    static func record(_ result: Result<CheckResult, ShopperError>, in store: ThreadStore = .shared) -> VerdictSnippetIntent {
        var snippet = VerdictSnippetIntent()
        switch result {
        case let .success(check):
            let product = check.product
            let id = store.startThread(for: product)
            store.loadReport(for: id)
            snippet.verdict = product.verdict.rawValue
            snippet.isSampleData = product.isSampleData
            snippet.productId = product.productId
        case let .failure(error):
            snippet.failure = error.message
        }
        return snippet
    }
}

// The snippet's More Details button. Runs in the app in the foreground and opens the product's thread.
@available(iOS 26.0, *)
struct OpenProductIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Product"
    static let isDiscoverable = false
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Product") var productId: String

    init() {}

    init(productId: String) {
        self.productId = productId
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        ThreadStore.shared.openProduct(productId)
        return .result()
    }
}

enum ScreenshotFile {
    // Where a handed-over file lives. Only the first three are temporary copies this app may delete.
    enum Kind: String {
        case ownTemp, ownCaches, shortcutsTemp, userStorage, other

        var isTemporary: Bool { self == .ownTemp || self == .ownCaches || self == .shortcutsTemp }
    }

    // Where Shortcuts leaves Take Screenshot's PNG on an iPhone (seen on a real one: YCCO-10's device test).
    static let shortcutsTemp = "/var/mobile/tmp"

    // What happened to the file, for ScanDiagnostics: no name, path or content.
    struct Handoff {
        var fileBacked: Bool
        var bytes: Int
        var kind: Kind?
        var deleted: Bool?
    }

    // Copies the image into memory, then deletes the file only when it is a temporary copy: inside this app's
    // temp or cache folder, or Shortcuts' temp folder. A folder merely named "tmp" doesn't count, and anything in
    // Documents, Files, iCloud Drive or Photos is never deleted.
    static func readOnce(_ file: IntentFile) -> (Data, Handoff) {
        guard let url = file.fileURL else { return (file.data, Handoff(fileBacked: false, bytes: file.data.count)) }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let bytes = file.data.withUnsafeBytes { Data($0) }
        let kind = kind(of: url)
        var deleted: Bool?
        if kind.isTemporary {
            try? FileManager.default.removeItem(at: url)
            deleted = !FileManager.default.fileExists(atPath: url.path)
        }
        return (bytes, Handoff(fileBacked: true, bytes: bytes.count, kind: kind, deleted: deleted))
    }

    static func kind(of url: URL) -> Kind {
        kind(ofPath: canonical(url), temp: canonical(FileManager.default.temporaryDirectory), caches: canonical(URL.cachesDirectory))
    }

    // The real location: ".." and symlinks resolved, so a link placed in a temp folder is judged by its target.
    // /private/var and /var are the same place.
    static func canonical(_ url: URL) -> String {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        return path.hasPrefix("/private/") ? String(path.dropFirst("/private".count)) : path
    }

    static func kind(ofPath path: String, temp: String, caches: String) -> Kind {
        func under(_ root: String) -> Bool { path.hasPrefix(root.hasSuffix("/") ? root : root + "/") }
        let userFolders = ["/Documents/", "/File Provider Storage/", "/Mobile Documents/", "/Media/DCIM/", "/Media/PhotoData/"]
        if userFolders.contains(where: { path.contains($0) }) { return .userStorage }
        if under(temp) { return .ownTemp }
        if under(caches) { return .ownCaches }
        if under(shortcutsTemp) { return .shortcutsTemp }
        return .other
    }
}
