// Target membership: app only. Replaces the template's App file.
import SwiftUI
import ActivityKit
import UserNotifications

@MainActor
final class Router: ObservableObject {
    static let shared = Router()
    @Published var openKey: String?

    // notyet://scan/<scanKey>
    func handle(_ url: URL) {
        guard url.scheme == "notyet", url.host == "scan" else { return }
        let key = url.lastPathComponent
        if !key.isEmpty { openKey = key }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Tapping a buy reminder opens that product.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let key = response.notification.request.content.userInfo["scanKey"] as? String, !key.isEmpty {
            await MainActor.run { Router.shared.openKey = key }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

struct ScanKey: Identifiable { let id: String }

@main
struct NotYetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var router = Router.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(router)
                .task {
                    // Screenshot runs pass -screenshots so no permission alert covers the screen.
                    if !ProcessInfo.processInfo.arguments.contains("-screenshots") {
                        await Reminders.requestPermission()
                    }
                }
                // -demoLiveActivity YES: the scan pop-up with no Shortcut (mock mode only).
                .task { await DemoLiveActivity.runIfRequested() }
                .onOpenURL { url in
                    router.handle(url)
                    // The pop-up has done its job once they're in the app.
                    Task {
                        for activity in Activity<ScanAttributes>.activities {
                            await activity.end(nil, dismissalPolicy: .immediate)
                        }
                    }
                }
                .sheet(item: Binding(
                    get: { router.openKey.map { ScanKey(id: $0) } },
                    set: { router.openKey = $0?.id })) { key in
                    NavigationStack {
                        ReportLoader(key: key.id)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { router.openKey = nil }
                                        .tint(Palette.textPrimary)
                                }
                            }
                            // The report scrolls under a bar of the same near-black, not a grey one.
                            .toolbarBackground(Palette.canvas, for: .navigationBar)
                    }
                    .environmentObject(router)
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Palette.canvas)
                    .preferredColorScheme(.dark)
                }
        }
    }
}
