// Target membership: app only. Home shows the latest verdict as the full report. With nothing
// checked yet, it shows the ways to check a product: Back Tap (with a way to set it up), a
// screenshot, or asking in Search. The blue light sits behind that empty state only.
import SwiftUI
import PhotosUI

struct HomeView: View {
    @EnvironmentObject var router: Router
    @Environment(\.scenePhase) private var scenePhase
    @State private var latestKey: String?
    @State private var loaded = false
    @State private var pick: PhotosPickerItem?
    @State private var showPicker = false
    @State private var showSetup = false
    // Why the last screenshot check didn't start, with what to do.
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            Group {
                if let key = latestKey {
                    VStack(alignment: .leading, spacing: 0) {
                        ScreenTitle("Latest check")
                            .padding(.horizontal, Spacing.screenMargin)
                            .padding(.bottom, 4)
                        ReportLoader(key: key).id(key)
                    }
                } else if loaded {
                    emptyState
                        .transition(.opacity)
                } else {
                    HoppingDots(color: Palette.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .animation(Motion.emptyStateSwap, value: loaded)
            .background(Palette.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showPicker = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.badge.plus")
                            Text("Check")
                        }
                    }
                    .accessibilityLabel("Check a screenshot")
                }
            }
            .settingsButton()
            .photosPicker(isPresented: $showPicker, selection: $pick, matching: .images)
            .safeAreaInset(edge: .bottom) {
                if let notice {
                    FailureNote(
                        message: notice,
                        action: { self.notice = nil; showPicker = true },
                        onDismiss: { self.notice = nil }
                    )
                    .padding(.leading, 14)
                    .padding(.trailing, 4)
                    .padding(.vertical, 4)
                    .glassSurface(cornerRadius: Radius.notice)
                    .padding(.horizontal, Spacing.screenMargin)
                    .padding(.bottom, 8)
                    .transition(.rise)
                }
            }
            .animation(Motion.rise, value: notice)
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

    // MARK: Nothing checked yet

    private var emptyState: some View {
        ZStack {
            BackdropGradient()
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle("Home")
                Spacer(minLength: 24)
                Image(systemName: "hand.tap")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Palette.textSecondary)
                    .accessibilityHidden(true)
                    .padding(.bottom, 14)
                Text("Tap the back of your phone on any product.")
                    .textStyle(.statement(size: 28))
                    .lineSpacing(8)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.titleToForm)

                Button { showSetup = true } label: {
                    HStack(spacing: Spacing.rowIconToText) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Set up Back Tap")
                                .textStyle(.cardTitle)
                                .foregroundStyle(Palette.textPrimary)
                            Text("Accessibility, Touch, Back Tap")
                                .textStyle(.caption)
                                .foregroundStyle(.white.opacity(0.82))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    .padding(.leading, Spacing.cardLeading)
                    .padding(.trailing, Spacing.cardTrailing + 4)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(GlassCardButtonStyle())
                .padding(.bottom, 16)

                Button("Check a screenshot") { showPicker = true }
                    .buttonStyle(KeyButtonStyle())

                Label("Or ask about it in Search", systemImage: "magnifyingglass")
                    .textStyle(.caption)
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, Spacing.screenMargin)
        }
        .sheet(isPresented: $showSetup) {
            SettingsSheet().preferredColorScheme(.dark)
        }
    }

    // MARK: Loading and checking

    private func refresh() async {
        let items = (try? await ScanAPI.fetchHistory()) ?? []
        latestKey = items.first?.scanKey
        loaded = true
    }

    private func check(_ item: PhotosPickerItem) async {
        defer { pick = nil }
        notice = nil
        guard let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty else {
            notice = "Couldn't open that image. Pick another screenshot."
            return
        }
        let key = UUID().uuidString
        let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.7) ?? data
        router.openKey = key // the report sheet polls until the scan exists
        do {
            _ = try await ScanAPI.submit(imageData: jpeg, scanKey: key, timeout: 60)
        } catch let error as URLError where Self.isOffline(error) {
            // The scan never reached the server, so the sheet would dig forever: close it and say why.
            if router.openKey == key { router.openKey = nil }
            notice = "No connection. Check your signal, then try again."
        } catch {
            // Slow or failed quick pass: the scan may still finish, and the sheet keeps polling.
        }
    }

    private static func isOffline(_ error: URLError) -> Bool {
        [.notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dataNotAllowed]
            .contains(error.code)
    }
}
