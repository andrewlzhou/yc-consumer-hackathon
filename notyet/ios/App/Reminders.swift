// Target membership: app only. Local notifications: no paid developer account needed.
import Foundation
import UserNotifications

enum Reminders {
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Fires at 9 AM on the buy date. If the date is missing or in the past, fires in 10 seconds (handy on stage).
    static func scheduleBuyReminder(scanKey: String, productName: String, buyDate: String?, body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Time to buy: \(productName)"
        content.body = body
        content.sound = .default
        content.userInfo = ["scanKey": scanKey]

        let trigger: UNNotificationTrigger
        if let buyDate, let date = ISO8601DateFormatter().date(from: buyDate + "T12:00:00Z"), date > .now {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
            comps.hour = 9
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        } else {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        }
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "buy-\(scanKey)", content: content, trigger: trigger))
    }

    /// Stage demo: same reminder, 10 seconds from now.
    static func demoReminder(scanKey: String, productName: String, body: String) {
        scheduleBuyReminder(scanKey: scanKey, productName: productName, buyDate: nil, body: body)
    }
}
