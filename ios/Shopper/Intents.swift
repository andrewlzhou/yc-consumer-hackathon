import AppIntents
import Foundation
import ShopperKit
import SwiftUI
import UniformTypeIdentifiers

// Shortcut path: "Take Screenshot" -> this intent. Runs without opening the app and answers with a dialog and snippet.
struct CheckScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Price in Screenshot"
    static let description = IntentDescription("Reads the product on screen on this iPhone and asks whether it is worth buying now. The screenshot never leaves the phone.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Screenshot", supportedContentTypes: [.image])
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let fileURL = screenshot.fileURL
        var outcome: ScanOutcome
        do {
            let data = screenshot.data
            outcome = await ScanPipeline.run(imageData: data, deviceId: DeviceIdentity.current())
        }
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
            outcome.tempFileDeleted = !FileManager.default.fileExists(atPath: fileURL.path)
        }
        log.info("screenshot intent: file-backed=\(fileURL != nil, privacy: .public) deleted=\(outcome.tempFileDeleted ?? false, privacy: .public)")
        let finished = outcome
        await MainActor.run { AppModel.shared.remember(finished) }
        return .result(dialog: IntentDialog(stringLiteral: finished.dialog), view: ResultSnippet(outcome: finished))
    }
}

// Share-sheet path: a Shortcut that receives a link from Safari or a store app, or any link the user passes in.
struct CheckLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Price of Link"
    static let description = IntentDescription("Asks whether the product at this store link is worth buying now.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Link")
    var url: URL

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let outcome = await ScanPipeline.run(url: url, deviceId: DeviceIdentity.current())
        await MainActor.run { AppModel.shared.remember(outcome) }
        return .result(dialog: IntentDialog(stringLiteral: outcome.dialog), view: ResultSnippet(outcome: outcome))
    }
}

struct ShopperShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: CheckScreenshotIntent(), phrases: ["Check price with \(.applicationName)"],
                    shortTitle: "Check Screenshot", systemImageName: "tag")
        AppShortcut(intent: CheckLinkIntent(), phrases: ["Check link with \(.applicationName)"],
                    shortTitle: "Check Link", systemImageName: "link")
    }
}

struct ResultSnippet: View {
    let outcome: ScanOutcome

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let response = outcome.response {
                VerdictBadge(verdict: response.verdict)
                if let title = response.matchedTitle { Text(title).font(.subheadline).lineLimit(2) }
                Text(response.reason).font(.footnote)
                HStack {
                    Text("Confidence \(Int((response.confidence * 100).rounded()))%")
                    if response.isSampleData { Text("Sample data").foregroundStyle(.orange) }
                }
                .font(.caption)
            } else {
                Text(outcome.error?.message ?? ShopperError.noProduct.message).font(.footnote)
            }
            Text(String(format: "OCR %.2fs · network %.2fs · total %.2fs", outcome.times.ocr, outcome.times.network, outcome.times.total))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
    }
}
