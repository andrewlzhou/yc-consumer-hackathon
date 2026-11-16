import AppIntents
import Foundation
import ShopperKit
import SwiftUI
import UniformTypeIdentifiers

// Shortcut path: "Take Screenshot" -> this intent. Runs without opening the app and answers with a small snippet.
struct CheckScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Price in Screenshot"
    static let description = IntentDescription("Reads the product on screen on this iPhone and asks whether it is worth buying now. The screenshot never leaves the phone.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Screenshot", supportedContentTypes: [.image])
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let (bytes, cleanup) = readOnce(screenshot)
        var outcome = await ScanPipeline.run(imageData: bytes, deviceId: DeviceIdentity.current())
        outcome.tempFileDeleted = cleanup
        let finished = outcome
        await MainActor.run { AppModel.shared.remember(finished) }
        return .result(view: ResultSnippet(outcome: finished))
    }
}

// Copies the image bytes into memory under security-scoped access, then deletes the file when it is a temporary copy:
// in this app's container or a temp/cache folder. On the real phone Shortcuts hands "Take Screenshot" over as a PNG
// in its own temp area with removedOnCompletion off, so that copy is deleted too. Files from Files or Photos
// (Documents, File Provider storage) are never deleted.
func readOnce(_ file: IntentFile) -> (Data, Bool?) {
    guard let url = file.fileURL else {
        recordHandoff(["fileBacked": false, "bytes": file.data.count])
        return (file.data, nil)
    }
    let scoped = url.startAccessingSecurityScopedResource()
    let bytes = file.data.withUnsafeBytes { Data($0) }
    var deleted: Bool?
    let path = url.resolvingSymlinksInPath().path
    let ownFolders = [FileManager.default.temporaryDirectory, URL(fileURLWithPath: NSHomeDirectory())]
        .map { $0.resolvingSymlinksInPath().path + "/" }
    let owned = ownFolders.contains { path.hasPrefix($0) }
    let temporary = owned || path.contains("/tmp/") || path.contains("/Library/Caches/")
    if temporary {
        try? FileManager.default.removeItem(at: url)
        deleted = !FileManager.default.fileExists(atPath: path)
    }
    if scoped { url.stopAccessingSecurityScopedResource() }
    recordHandoff(["fileBacked": true, "bytes": bytes.count, "owned": owned, "deleted": deleted ?? false,
                   "removedOnCompletion": file.removedOnCompletion, "type": file.type?.identifier ?? "unknown",
                   "temporary": temporary, "folder": folderKind(path)])
    log.info("screenshot file: bytes=\(bytes.count, privacy: .public) owned=\(owned, privacy: .public) deleted=\(deleted ?? false, privacy: .public) removedOnCompletion=\(file.removedOnCompletion, privacy: .public)")
    return (bytes, deleted)
}

// Where a handed-over file lived, without its name: e.g. "Containers/Data/Application/*/tmp".
func folderKind(_ path: String) -> String {
    let parts = (path as NSString).deletingLastPathComponent.split(separator: "/").map(String.init)
    return parts.map { $0.count == 36 && $0.contains("-") ? "*" : $0 }.suffix(5).joined(separator: "/")
}

// How Shortcuts handed the screenshot over (no image content), kept for the device test in docs/ios/device-test.md.
func recordHandoff(_ facts: [String: Any]) {
    var entry = facts
    entry["at"] = Date().timeIntervalSince1970
    UserDefaults.standard.set(entry, forKey: "shopper.lastHandoff")
}

// Share-sheet path: a Shortcut that receives a link from Safari or a store app, or any link the user passes in.
struct CheckLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Price of Link"
    static let description = IntentDescription("Asks whether the product at this store link is worth buying now.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Link")
    var url: URL

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let outcome = await ScanPipeline.run(url: url, deviceId: DeviceIdentity.current())
        await MainActor.run { AppModel.shared.remember(outcome) }
        return .result(view: ResultSnippet(outcome: outcome))
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

// The popup over the store app: a colored verdict word and one short line. iOS decides the outer popup size.
struct ResultSnippet: View {
    let outcome: ScanOutcome

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let response = outcome.response {
                Text(Self.word(response.verdict))
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Self.color(response.verdict))
                Text(Self.short(response.reason) + (response.isSampleData ? " · sample" : ""))
                    .font(.footnote)
                    .lineLimit(1)
            } else {
                Text(Self.short(outcome.error?.message ?? ShopperError.noProduct.message))
                    .font(.footnote)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    static func word(_ verdict: Verdict) -> String {
        switch verdict {
        case .buyNow: "BUY"
        case .wait: "WAIT"
        case .considerAlternative: "LOOK ELSEWHERE"
        case .investigate: "INDETERMINATE"
        }
    }

    static func color(_ verdict: Verdict) -> Color {
        switch verdict {
        case .buyNow: .green
        case .wait: .orange
        case .considerAlternative: .blue
        case .investigate: .gray
        }
    }

    // First sentence, cut at a word boundary to about 60 characters.
    static func short(_ text: String) -> String {
        let sentence = text.components(separatedBy: ". ").first?.trimmingCharacters(in: CharacterSet(charactersIn: ". ")) ?? text
        guard sentence.count > 60 else { return sentence }
        let cut = sentence.prefix(60)
        return String(cut[..<(cut.lastIndex(of: " ") ?? cut.endIndex)]) + "…"
    }
}
