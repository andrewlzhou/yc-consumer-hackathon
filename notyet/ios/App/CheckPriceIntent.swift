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
        // The bar fills over the longest the quick check may take, so it never reads "done" while
        // the phone is still waiting. An answer that comes sooner simply replaces it.
        let quickTimeout: TimeInterval = 25
        let working = ScanAttributes.ContentState(
            stage: "working", headline: "Finding the product…", productName: nil,
            verdict: nil, scanKey: scanKey, etaEnd: start.addingTimeInterval(quickTimeout))
        let activity = try? Activity<ScanAttributes>.request(
            attributes: ScanAttributes(startedAt: start),
            content: ActivityContent(state: working, staleDate: nil),
            pushType: nil)

        let jpeg = UIImage(data: screenshot.data)?.jpegData(compressionQuality: 0.7) ?? screenshot.data

        do {
            // The quick pass. The deep report keeps running on Convex after this returns.
            let quick = try await ScanAPI.submit(imageData: jpeg, scanKey: scanKey, timeout: quickTimeout)
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
            // A timeout means the server may still finish; anything else means it probably won't.
            let timedOut = (error as? URLError)?.code == .timedOut
            let failed = ScanAttributes.ContentState(
                stage: "failed",
                headline: timedOut ? "Still checking. Tap to follow it in the app." : "Couldn't check this one. Tap to open the app.",
                productName: nil, verdict: nil, scanKey: scanKey, etaEnd: Date())
            await activity?.update(ActivityContent(state: failed, staleDate: nil))
        }
        return .result()
    }
}
