// Target membership: app only.
// Shows up in the Shortcuts app as "Check Price". The shortcut is:
// Take Screenshot -> Resize Image (1200 wide) -> Check Price (Screenshot = Resized Image)
import AppIntents
import ActivityKit
import UIKit

struct CheckPriceIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Check Price"
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Screenshot", supportedContentTypes: [.image])
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult {
        // One pop-up at a time. Starting a second one while another is live can fail.
        for old in Activity<ScanAttributes>.activities {
            await old.end(nil, dismissalPolicy: .immediate)
        }

        let scanKey = UUID().uuidString
        let start = Date()
        let working = ScanAttributes.ContentState(
            stage: "working", headline: "Finding the product…", productName: nil,
            verdict: nil, scanKey: scanKey, etaEnd: start.addingTimeInterval(14))
        let activity = try? Activity<ScanAttributes>.request(
            attributes: ScanAttributes(startedAt: start),
            content: ActivityContent(state: working, staleDate: nil),
            pushType: nil)

        let jpeg = UIImage(data: screenshot.data)?.jpegData(compressionQuality: 0.7) ?? screenshot.data

        do {
            // The quick pass. The deep report keeps running on Convex after this returns.
            let quick = try await ScanAPI.submit(imageData: jpeg, scanKey: scanKey, timeout: 25)
            let ready = ScanAttributes.ContentState(
                stage: "ready", headline: quick.oneLiner, productName: quick.productName,
                verdict: quick.verdict, scanKey: scanKey, etaEnd: Date(), retailer: quick.retailer)
            // The alert is the "glitter": the Dynamic Island expands with sound and haptics.
            await activity?.update(
                ActivityContent(state: ready, staleDate: nil),
                alertConfiguration: AlertConfiguration(
                    title: LocalizedStringResource(stringLiteral: quick.productName),
                    body: LocalizedStringResource(stringLiteral: quick.oneLiner),
                    sound: .default))
        } catch {
            let failed = ScanAttributes.ContentState(
                stage: "failed", headline: "Still digging. Tap to see your verdict.",
                productName: nil, verdict: nil, scanKey: scanKey, etaEnd: Date())
            await activity?.update(ActivityContent(state: failed, staleDate: nil))
        }
        return .result()
    }
}
