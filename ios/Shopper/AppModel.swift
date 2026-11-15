import Foundation
import ShopperKit

// App-wide state: backend client, anonymous device id, and a local productId -> title cache for the watchlist.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var deviceId = DeviceIdentity.current()
    @Published var lastScan: ScanOutcome?
    @Published private(set) var titles: [String: String] = UserDefaults.standard.dictionary(forKey: "shopper.titles") as? [String: String] ?? [:]

    nonisolated static var config: BackendConfig {
        let info = Bundle.main.infoDictionary ?? [:]
        let host = (info["ShopperBackendHost"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "scintillating-caterpillar-190.convex.site"
        return BackendConfig(baseURL: URL(string: "https://" + host)!, apiKey: info["ShopperAPIKey"] as? String)
    }

    var client: ShopperClient { ShopperClient(config: Self.config, deviceId: deviceId) }
    var hasKey: Bool { !(Self.config.apiKey ?? "").isEmpty }

    func remember(_ outcome: ScanOutcome) {
        lastScan = outcome
        if let id = outcome.response?.productId, let title = outcome.response?.matchedTitle ?? outcome.extract.title {
            titles[id] = title
            UserDefaults.standard.set(titles, forKey: "shopper.titles")
        }
    }

    func newTestDevice() {
        deviceId = DeviceIdentity.reset(prefix: "ios-test-")
    }
}
