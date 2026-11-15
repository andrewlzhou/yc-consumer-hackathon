import ShopperKit
import SwiftUI

// The notification inbox: the fallback for push until APNs credentials exist.
struct InboxView: View {
    @EnvironmentObject var model: AppModel
    @State private var notes: [InboxNotification] = []
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if let error { Text(error).foregroundStyle(.red) }
                if notes.isEmpty && error == nil { Text("No new alerts.").foregroundStyle(.secondary) }
                ForEach(notes) { note in
                    NavigationLink { ReportView(productId: note.productId) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                VerdictBadge(verdict: note.verdict).scaleEffect(0.8)
                                if note.simulated { Text("Simulated").font(.caption).foregroundStyle(.orange) }
                            }
                            Text(note.title).font(.subheadline)
                            Text(note.body).font(.caption)
                            Text(String(format: "$%.2f · %@", note.price, note.trigger.replacingOccurrences(of: "_", with: " "))).font(.caption2)
                        }
                    }
                }
            }
            .navigationTitle("Inbox")
            .toolbar {
                if !notes.isEmpty { Button("Mark all read") { Task { await acknowledge() } } }
            }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        do {
            notes = try await model.client.inbox()
            error = nil
        } catch let e as ShopperError {
            error = e.message
        } catch {
            self.error = ShopperError.network.message
        }
    }

    private func acknowledge() async {
        do {
            try await model.client.acknowledge(ids: notes.map(\.id))
            await load()
        } catch let e as ShopperError {
            error = e.message
        } catch {
            self.error = ShopperError.network.message
        }
    }
}
