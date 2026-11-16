// Shortcut actions. Back Tap runs a shortcut: Take Screenshot, then "Check Price in Screenshot". The check runs in
// the background so the store app stays in front, and iOS shows the compact result (CompactVerdictView) as a
// snippet. Its Details button runs OpenProductIntent, which brings Check Price forward on that product's thread.
// The system's own Done button and the platter around the snippet are drawn by iOS and can't be changed.
// iOS 26+: interactive snippets (SnippetIntent) and supportedModes are new there.
import AppIntents
import Foundation
import ShopperKit

@available(iOS 26.0, *)
struct CheckScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Price in Screenshot"
    static let description = IntentDescription("Reads the product on screen on this iPhone and says whether to buy it now. The screenshot never leaves the phone.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Screenshot", supportedContentTypes: [.image])
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult & ShowsSnippetIntent {
        let result = await CheckRunner.run(imageData: ScreenshotFile.readOnce(screenshot))
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
        let result = await CheckRunner.run(url: url)
        return .result(snippetIntent: await VerdictSnippetIntent.record(result))
    }
}

// The snippet. Its parameters are the little the popup shows; iOS may run it again when the Details button is
// tapped, so it has no side effects.
@available(iOS 26.0, *)
struct VerdictSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Price Verdict"

    // Verdict's raw value; nil when the check failed and the reason is the failure.
    @Parameter(title: "Verdict") var verdict: String?
    @Parameter(title: "Reason") var reason: String
    @Parameter(title: "Sample data", default: false) var isSampleData: Bool
    @Parameter(title: "Product") var productId: String?

    init() {}

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: CompactVerdictView(verdict: verdict.flatMap(Verdict.init(rawValue:)), reason: reason,
                                         isSampleData: isSampleData, productId: productId))
    }

    // Keeps a successful check as a new thread (fetching its report), then builds the snippet.
    @MainActor
    static func record(_ result: Result<CheckResult, ShopperError>) -> VerdictSnippetIntent {
        var snippet = VerdictSnippetIntent()
        switch result {
        case let .success(check):
            let product = check.product
            let id = ThreadStore.shared.startThread(for: product)
            ThreadStore.shared.loadReport(for: id)
            snippet.verdict = product.verdict.rawValue
            snippet.reason = ShortReason.make(product.summary)
            snippet.isSampleData = product.isSampleData
            snippet.productId = product.productId
        case let .failure(error):
            snippet.reason = error.message
        }
        return snippet
    }
}

// The snippet's Details button. Runs in the app in the foreground and opens the product's thread.
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
        await ThreadStore.shared.openProduct(productId)
        return .result()
    }
}

enum ScreenshotFile {
    // Copies the image into memory, then deletes the file only when it is a temporary copy in a tmp or cache folder:
    // on a real iPhone, Shortcuts hands Take Screenshot over as a PNG in /var/mobile/tmp/... that it leaves in place
    // (YCCO-10's device test). Anything in Documents, Files or Photos is never deleted.
    static func readOnce(_ file: IntentFile) -> Data {
        guard let url = file.fileURL else { return file.data }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let bytes = file.data.withUnsafeBytes { Data($0) }
        if isTemporary(url.resolvingSymlinksInPath().path) { try? FileManager.default.removeItem(at: url) }
        return bytes
    }

    static func isTemporary(_ path: String) -> Bool {
        (path.contains("/tmp/") || path.contains("/Library/Caches/")) && !path.contains("/Documents/")
    }
}
