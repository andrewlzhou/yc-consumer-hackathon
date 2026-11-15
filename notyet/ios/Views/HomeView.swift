// Target membership: app only. Home shows the latest verdict as the full report.
import SwiftUI
import PhotosUI

struct HomeView: View {
    @EnvironmentObject var router: Router
    @Environment(\.scenePhase) private var scenePhase
    @State private var latestKey: String?
    @State private var loaded = false
    @State private var pick: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Group {
                if let key = latestKey {
                    ReportLoader(key: key).id(key)
                } else if loaded {
                    emptyState
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Theme.paper)
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PhotosPicker(selection: $pick, matching: .images) {
                        Image(systemName: "photo.badge.plus")
                    }
                    .accessibilityLabel("Check a screenshot")
                }
            }
            .settingsButton()
            .task { await refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refresh() } }
            }
            .onChange(of: router.openKey) { _, _ in Task { await refresh() } }
            .onChange(of: pick) { _, item in
                guard let item else { return }
                Task { await check(item) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.tap").font(.system(size: 40)).foregroundStyle(Theme.prussianLight)
            Text("Tap the back of your phone on any product.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.ink)
            PhotosPicker(selection: $pick, matching: .images) {
                Text("Check a screenshot")
            }
            .buttonStyle(SharpButtonStyle())
            .frame(maxWidth: 260)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func refresh() async {
        let items = (try? await ScanAPI.fetchHistory()) ?? []
        latestKey = items.first?.scanKey
        loaded = true
    }

    private func check(_ item: PhotosPickerItem) async {
        defer { pick = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let key = UUID().uuidString
        let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.7) ?? data
        router.openKey = key // the report sheet polls until the scan exists
        _ = try? await ScanAPI.submit(imageData: jpeg, scanKey: key, timeout: 60)
    }
}
