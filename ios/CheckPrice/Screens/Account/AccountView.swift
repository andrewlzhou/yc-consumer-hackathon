// The Account tab, laid out the way Instagram's profile page is: handle and a gear (opens the
// Settings sheet) in the top bar, avatar beside three counts, name and bio (each only when set),
// Edit profile and Share profile keys, then a grid of the user's saved threads. The counts are
// Check Price's own: checks, saved threads, and the money saved by waiting on saved threads.
import SwiftUI

struct AccountView: View {
    @AppStorage(ProfileKeys.name) private var name = ""
    @AppStorage(ProfileKeys.handle) private var handle = ""
    @AppStorage(ProfileKeys.bio) private var bio = ""
    @State private var editing = false
    @State private var settingsOpen = false

    @Environment(ThreadStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    actions.padding(.top, 16)
                    ProfileGrid(threads: store.saved)
                        .padding(.top, 24)
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, 32)
            }
            // ContentView draws the backdrop behind every tab; keep the stack see-through.
            .containerBackground(.clear, for: .navigation)
            .toolbar {
                // The handle is profile info, as on Instagram, not a screen title, so it stays.
                // With no handle set the corner is empty rather than saying "Account".
                ToolbarItem(placement: .topBarLeading) {
                    if !handle.isEmpty {
                        Text(handle)
                            .font(.hiragino(.w6, size: 20, relativeTo: .title3))
                            .tracking(-0.2)
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { settingsOpen = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $settingsOpen) {
                AccountSettingsView()
                    .presentationBackground { AppBackdrop() }
            }
            .sheet(isPresented: $editing) {
                EditProfileSheet()
                    .presentationDragIndicator(.visible)
                    .presentationBackground { AppBackdrop() }
            }
        }
    }

    // Avatar and the three counts on one row, then the name and bio under them.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 20) {
                ProfileAvatar(name: name, size: 84)
                HStack(spacing: 0) {
                    ProfileStat(value: Text("\(store.threads.count)"), number: Double(store.threads.count), label: "Checks")
                    ProfileStat(value: Text("\(store.saved.count)"), number: Double(store.saved.count), label: "Saved")
                    let waited = SavedByWaiting.total(store.saved)
                    ProfileStat(value: Text(SavedByWaiting.format(waited)), number: Double(waited), label: "Saved by waiting")
                }
            }
            if !name.isEmpty {
                Text(name)
                    .textStyle(.cardTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.top, 14)
            }
            if !bio.isEmpty {
                Text(bio)
                    .textStyle(.body)
                    .lineSpacing(4)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 6)
            }
        }
    }

    // Edit profile and Share profile, side by side at equal width, as on Instagram.
    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                editing = true
            } label: {
                Text("Edit profile").frame(maxWidth: .infinity)
            }
            .buttonStyle(KeyButtonStyle(tone: .secondary))

            ShareLink(item: shareText) {
                Text("Share profile").frame(maxWidth: .infinity)
            }
            .buttonStyle(KeyButtonStyle(tone: .secondary))
        }
    }

    // There is no profile web page yet, so sharing sends a line of text, not a link.
    private var shareText: String {
        let who = handle.isEmpty ? (name.isEmpty ? "I'm" : "\(name) is") : "@\(handle) is"
        return "\(who) checking prices with Check Price."
    }
}

// Where the profile fields are kept on the device. Nothing is sent anywhere.
enum ProfileKeys {
    static let name = "profileName"
    static let handle = "profileHandle"
    static let bio = "profileBio"
}

// A round avatar: the name's initials, or a person symbol when there is no name, on a warm grey
// pair with a white top sheen (worldscape F/People/PersonRow.swift).
struct ProfileAvatar: View {
    let name: String
    var size: CGFloat = 84

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    var body: some View {
        ZStack {
            Circle().fill(
                LinearGradient(colors: [Color(hex: 0x76746E), Palette.stone], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            Circle().fill(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: .center))
            if initials.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                Text(initials)
                    .font(.hiragino(.w6, size: size * 0.34, relativeTo: .title))
                    .foregroundStyle(.white)
                    .dropShadow(Shadows.labelOnColor)
            }
        }
        .frame(width: size, height: size)
        .overlay { Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1) }
        .accessibilityHidden(true)
    }
}

// One count in the stats row: the number on top, its name under it, centred.
private struct ProfileStat: View {
    let value: Text
    let number: Double
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            value
                .font(.hiragino(.w6, size: 19, relativeTo: .title3))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText(value: number))
                .animation(Motion.valueChange, value: number)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .textStyle(.caption)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
    }
}

// The money a saved thread stands to save by waiting: its price minus the low end of its
// projected low, never below zero. Prices are demo strings like "$349" and "$309–$319".
enum SavedByWaiting {
    static func total(_ threads: [ShoppingThread]) -> Int {
        threads.reduce(0) { $0 + amount($1.product) }
    }

    static func amount(_ product: Product) -> Int {
        guard let price = firstDollars(product.price), let low = firstDollars(product.projectedLow) else { return 0 }
        return max(0, price - low)
    }

    static func format(_ dollars: Int) -> String { "$\(dollars)" }

    // The first whole-dollar number in the string: "$1,299.99" → 1299.
    private static func firstDollars(_ text: String) -> Int? {
        var digits = ""
        for character in text.drop(while: { !$0.isNumber }) {
            if character.isNumber { digits.append(character) }
            else if character == "," { continue }
            else { break }
        }
        return Int(digits)
    }
}
