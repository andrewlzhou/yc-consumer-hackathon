// Target membership: app only. Discover rows, and the blue "Ask" bar with a mic for voice.
// Asking shows the question as a bubble with hopping dots and the step it's on, the way a chat
// reply arrives (worldscape F/Chat), then opens the report sheet. A failure stays by the bar and
// says what to do.
import SwiftUI
import UIKit

struct SearchView: View {
    @EnvironmentObject var router: Router
    @StateObject private var voice = VoiceInput()
    @FocusState private var barFocused: Bool
    @State private var query = ""
    // The question on its way (or the one that failed), shown as a bubble above the bar.
    @State private var asked: String?
    @State private var failure: String?
    @State private var stage = 0
    @State private var askTask: Task<Void, Never>?
    @State private var askToken = UUID()

    // What the wait is spent on, by seconds since asking, in the report sheet's words.
    // `ScanAPI.ask` reports no progress, so these advance on a clock, like the Live Activity's bar.
    private static let stages: [(after: Double, text: String)] = [
        (0, DigStage.finding.label + "…"),
        (3, DigStage.prices.label + "…"),
        (9, DigStage.history.label + "…"),
        (20, DigStage.verdict.label + "…"),
    ]

    private var isAsking: Bool { askTask != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ScreenTitle("Search")
                        .padding(.bottom, 14)
                    SectionLabel("Discover")
                        .padding(.leading, 4)
                    FlatCard {
                        VStack(spacing: 0) {
                            NavigationLink {
                                DiscoverListView(kind: "lowest", title: "Lowest prices")
                            } label: {
                                DiscoverRow(title: "Lowest prices", symbol: "arrow.down")
                            }
                            .buttonStyle(ListRowButtonStyle())
                            Hairline().padding(.leading, 70)
                            NavigationLink {
                                DiscoverListView(kind: "deals", title: "Best deals")
                            } label: {
                                DiscoverRow(title: "Best deals", symbol: "tag")
                            }
                            .buttonStyle(ListRowButtonStyle())
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Radius.listCard, style: .continuous))
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.canvas)
            .settingsButton()
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    status
                    askBar
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, 8)
                .animation(Motion.rise, value: asked)
                .animation(Motion.dotsToText, value: failure)
                .animation(Motion.rise, value: voice.problem)
            }
            .onChange(of: voice.transcript) { _, text in
                if !text.isEmpty { query = text }
            }
        }
    }

    // MARK: Above the bar

    @ViewBuilder private var status: some View {
        if let asked {
            VStack(alignment: .leading, spacing: 10) {
                Bubble(isPerson: true) {
                    Text(asked)
                        .textStyle(.body)
                        .lineSpacing(4)
                        .foregroundStyle(Palette.textPrimary)
                }
                .padding(.leading, 56)
                .frame(maxWidth: .infinity, alignment: .trailing)

                if let failure {
                    FailureNote(message: failure, action: { submit(asked) }, onDismiss: clearAsk)
                        .transition(.opacity)
                } else {
                    ThinkingLine(step: Self.stages[stage].text)
                        .padding(.leading, 4)
                        .transition(.opacity)
                }
            }
            .transition(.rise)
        } else if let problem = voice.problem {
            FailureNote(message: problem, actionTitle: "Settings", action: openSettings, onDismiss: { voice.problem = nil })
                .transition(.rise)
        }
    }

    // MARK: The bar

    // Worldscape's input bar: a blue capsule, 56pt for one line and growing to four, 17pt text,
    // a white arrow that's dim until there's something to send. While a question is on its way
    // the arrow becomes a square that stops it.
    private var askBar: some View {
        let canSend = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(alignment: .bottom, spacing: 0) {
            TextField(
                "Ask about any product",
                text: $query,
                prompt: Text("Ask about any product")
                    .font(Self.barFont)
                    .foregroundStyle(.white.opacity(0.74)),
                axis: .vertical
            )
            .font(Self.barFont)
            .foregroundStyle(.white)
            .tint(.white)
            .lineLimit(1...4)
            .submitLabel(.search)
            .focused($barFocused)
            .onSubmit { submit(query) }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Ask about any product")

            if !isAsking {
                micButton.transition(.opacity.combined(with: .scale(scale: 0.7)))
            }
            sendButton(canSend: canSend)
        }
        .padding(.leading, 22)
        .padding(.trailing, 6)
        .frame(minHeight: ControlHeight.inputBar)
        .background { InputBarSurface() }
        .animation(Motion.layout, value: query)
        .animation(Motion.appear, value: isAsking)
        // A vertical field may type a return instead of submitting; treat it as submit.
        .onChange(of: query) { _, text in
            guard text.contains("\n") else { return }
            query = text.replacingOccurrences(of: "\n", with: " ")
            submit(query)
        }
    }

    private static let barFont = Font.hiragino(.w4, size: 17, relativeTo: .body)

    private var micButton: some View {
        Button {
            voice.problem = nil
            voice.toggle()
        } label: {
            Image(systemName: voice.isListening ? "waveform" : "mic")
                .font(.system(size: 17, weight: .semibold))
                .symbolEffect(.variableColor.iterative, isActive: voice.isListening)
                .foregroundStyle(.white.opacity(voice.isListening ? 1 : 0.7))
                .frame(width: ControlHeight.minTouch, height: ControlHeight.minTouch)
                .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .padding(.bottom, (ControlHeight.inputBar - ControlHeight.minTouch) / 2)
        .accessibilityLabel(voice.isListening ? "Stop listening" : "Ask by voice")
    }

    private func sendButton(canSend: Bool) -> some View {
        let isLit = canSend || isAsking
        return Button {
            if isAsking { stop() } else { submit(query) }
        } label: {
            ZStack {
                Image(systemName: "arrow.up")
                    .font(.system(size: 19, weight: .semibold))
                    .opacity(isAsking ? 0 : 1)
                    .scaleEffect(isAsking ? 0.6 : 1)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .frame(width: 13, height: 13)
                    .opacity(isAsking ? 1 : 0)
                    .scaleEffect(isAsking ? 1 : 0.6)
            }
            .foregroundStyle(.white.opacity(isLit ? 1 : 0.6))
            .dropShadow(Shadows.sendArrow)
            .frame(width: ControlHeight.minTouch, height: ControlHeight.minTouch)
            .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .disabled(!isLit)
        .padding(.bottom, (ControlHeight.inputBar - ControlHeight.minTouch) / 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.72), value: isAsking)
        .accessibilityLabel(isAsking ? "Stop" : "Ask")
    }

    // MARK: Asking

    private func submit(_ text: String) {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        askTask?.cancel()
        if voice.isListening { voice.stop() }
        voice.problem = nil
        barFocused = false
        let token = UUID()
        askToken = token
        asked = q
        failure = nil
        stage = 0
        query = ""
        askTask = Task { await ask(q, token: token) }
    }

    private func ask(_ q: String, token: UUID) async {
        let clock = Task { await advanceStages() }
        defer {
            clock.cancel()
            if askToken == token { askTask = nil }
        }
        do {
            let quick = try await ScanAPI.ask(q)
            guard !Task.isCancelled, askToken == token else { return }
            asked = nil
            router.openKey = quick.scanKey
        } catch {
            guard !Task.isCancelled, askToken == token, !Self.isCancellation(error) else { return }
            failure = Self.message(for: error)
        }
    }

    private func advanceStages() async {
        for index in Self.stages.indices.dropFirst() {
            let wait = Self.stages[index].after - Self.stages[index - 1].after
            do { try await Task.sleep(for: .seconds(wait)) } catch { return }
            withAnimation(Motion.streamReflow) { stage = index }
        }
    }

    // Stops waiting and puts the question back in the bar to edit.
    private func stop() {
        askTask?.cancel()
        askTask = nil
        askToken = UUID()
        if let asked { query = asked }
        clearAsk()
    }

    private func clearAsk() {
        asked = nil
        failure = nil
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    // What went wrong, in words that say what to do next.
    private static func message(for error: Error) -> String {
        switch (error as? URLError)?.code {
        case .notConnectedToInternet?, .networkConnectionLost?, .cannotConnectToHost?, .dataNotAllowed?, .cannotFindHost?:
            return "No connection. Check your signal, then try again."
        case .timedOut?:
            return "That took too long. Try again, or use the exact model name."
        default:
            return "Couldn't find that product. Try the exact model name."
        }
    }
}

private struct DiscoverRow: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: Spacing.rowIconToText) {
            RoundIcon(systemName: symbol, size: ControlHeight.avatar)
            Text(title)
                .textStyle(.item)
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(.horizontal, Spacing.rowHorizontal)
        .frame(height: ControlHeight.row)
    }
}

struct DiscoverListView: View {
    let kind: String
    let title: String
    @State private var items: [DiscoverItem] = []
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle(title)
                    .padding(.bottom, 14)
                listContent
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Palette.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .animation(Motion.cardArrive, value: loading)
        .task {
            items = (try? await ScanAPI.fetchDiscover(kind: kind)) ?? []
            loading = false
        }
    }

    @ViewBuilder private var listContent: some View {
        if loading && items.isEmpty {
            HoppingDots(color: Palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 72)
        } else if items.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "tag")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Palette.textTertiary)
                Text("Nothing here yet.")
                    .textStyle(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 72)
        } else {
            FlatCard {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Hairline().padding(.leading, 70) }
                        NavigationLink {
                            ProductReportView(result: item.result, scanKey: nil)
                        } label: {
                            DiscoverItemRow(item: item)
                        }
                        .buttonStyle(ListRowButtonStyle())
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.listCard, style: .continuous))
            }
            .transition(.rise)
        }
    }
}

private struct DiscoverItemRow: View {
    let item: DiscoverItem

    var body: some View {
        HStack(spacing: Spacing.rowIconToText) {
            RoundIcon(systemName: Theme.productSymbol(item.result.product.name), size: ControlHeight.avatar)
            Text(item.result.product.name)
                .textStyle(.item)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(Theme.money(item.result.currentPrice))
                    .textStyle(.item)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
                if item.discount > 0 {
                    Text("\(item.discount)% off usual")
                        .textStyle(.footnote)
                        .foregroundStyle(Theme.buy)
                }
            }
        }
        .padding(.horizontal, Spacing.rowHorizontal)
        .frame(minHeight: ControlHeight.row)
    }
}

#Preview {
    SearchView().environmentObject(Router.shared).preferredColorScheme(.dark)
}
