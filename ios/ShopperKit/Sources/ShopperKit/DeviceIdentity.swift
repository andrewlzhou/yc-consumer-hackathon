import Foundation

// Anonymous random id made on first launch. Not authentication; it only keys the watchlist and rate limits.
public enum DeviceIdentity {
    static let key = "shopper.deviceId"

    public static func current(_ defaults: UserDefaults = .standard) -> String {
        if let id = defaults.string(forKey: key), !id.isEmpty { return id }
        return reset(defaults)
    }

    @discardableResult
    public static func reset(_ defaults: UserDefaults = .standard, prefix: String = "ios-") -> String {
        let id = prefix + UUID().uuidString.lowercased()
        defaults.set(id, forKey: key)
        return id
    }
}
