// The Account tab is the Settings page (owner, 2026-11-15), laid out after Grok's iOS Settings:
// "Settings" small and centred in the bar, a profile card (photo, name, email, chevron) that opens
// EditProfileSheet, then cards: the plan, Shopping, Notifications, App, About, and Sign out.
// Region, Currency, Preferred stores and the alert threshold push a choice list; toggles and
// choices are kept on the device with @AppStorage. Rows that open nothing have no chevron and
// aren't buttons. The plan, quiet hours and the profile defaults are dummy data (owner,
// 2026-11-15). ContentView draws the backdrop behind the tab; nothing here paints over it.
// Rows and cards are in SettingsParts.swift.
import SwiftUI

struct AccountView: View {
    @AppStorage(ProfileKeys.name) private var name = ProfileDefaults.name
    @AppStorage(ProfileKeys.handle) private var handle = ""
    @AppStorage(ProfileKeys.email) private var email = ProfileDefaults.email
    @AppStorage(SettingsKeys.region) private var region = SettingsOptions.regions[0]
    @AppStorage(SettingsKeys.currency) private var currency = SettingsOptions.currencies[0]
    @AppStorage(SettingsKeys.stores) private var stores = SettingsOptions.defaultStores
    @AppStorage(SettingsKeys.dropThreshold) private var dropThreshold = 10
    @AppStorage(SettingsKeys.priceDrops) private var priceDrops = true
    @AppStorage(SettingsKeys.weeklySummary) private var weeklySummary = true
    @AppStorage(SettingsKeys.restockAlerts) private var restockAlerts = false
    @AppStorage(SettingsKeys.haptics) private var haptics = true
    @State private var editing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Button { editing = true } label: { profileCard }
                        .buttonStyle(SettingsCardButtonStyle())
                        .accessibilityHint("Edit profile")
                    planSection
                    shoppingSection
                    notificationsSection
                    appSection
                    aboutSection
                    signOut
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollContentBackground(.hidden)
            .containerBackground(.clear, for: .navigation)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.hiragino(.w7, size: 16, relativeTo: .headline))
                        .foregroundStyle(Palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $editing) {
                EditProfileSheet()
                    .presentationDragIndicator(.visible)
                    .presentationBackground { AppBackdrop() }
            }
        }
    }

    // Photo, then the name (semibold) over the email (secondary). A user who cleared the name but
    // set a handle sees "@handle" on the top line instead.
    private var profileCard: some View {
        HStack(spacing: Spacing.rowIconToText) {
            ProfilePhoto(size: 56)
            VStack(alignment: .leading, spacing: 4) {
                if let title = profileTitle {
                    Text(title)
                        .font(.hiragino(.w6, size: 17, relativeTo: .body))
                        .foregroundStyle(Palette.textPrimary)
                }
                if !email.isEmpty {
                    Text(email)
                        .font(.hiragino(.w4, size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            SettingsChevron()
        }
        .padding(.horizontal, SettingsMetrics.horizontal)
        .padding(.vertical, 16)
        .background(SettingsSurface.fill, in: SettingsSurface.shape)
        .accessibilityElement(children: .combine)
    }

    private var profileTitle: String? {
        if !name.isEmpty { return name }
        return handle.isEmpty ? nil : "@\(handle)"
    }

    // Dummy plan and usage (owner, 2026-11-15); display only.
    private var planSection: some View {
        SettingsSection {
            SettingsRow(title: "Check Price Plus", symbol: "sparkles", value: "Active")
            SettingsSeparator()
            SettingsRow(title: "Checks this month", symbol: "checkmark.circle", value: "12 of 50")
        }
    }

    private var shoppingSection: some View {
        SettingsSection(title: "Shopping") {
            SettingsLinkRow(title: "Region", symbol: "globe", value: region) {
                SettingsChoiceList(options: SettingsOptions.regions, isSelected: { $0 == region }) { region = $0 }
            }
            SettingsSeparator()
            SettingsLinkRow(title: "Currency", symbol: "dollarsign.circle", value: currency) {
                SettingsChoiceList(options: SettingsOptions.currencies, isSelected: { $0 == currency }) { currency = $0 }
            }
            SettingsSeparator()
            SettingsLinkRow(title: "Preferred stores", symbol: "bag", value: StoreList.summary(stores)) {
                SettingsChoiceList(options: SettingsOptions.stores, isSelected: { StoreList.contains(stores, $0) }) {
                    stores = StoreList.toggling(stores, $0)
                }
            }
            SettingsSeparator()
            SettingsLinkRow(title: "Alert me when price drops", symbol: "arrow.down.circle", value: "\(dropThreshold)%") {
                SettingsChoiceList(
                    options: SettingsOptions.dropThresholds.map { "\($0)%" },
                    isSelected: { $0 == "\(dropThreshold)%" }
                ) { dropThreshold = Int($0.dropLast()) ?? dropThreshold }
            }
        }
    }

    private var notificationsSection: some View {
        SettingsSection(title: "Notifications") {
            SettingsToggleRow(title: "Price drops", symbol: "tag", isOn: $priceDrops)
            SettingsSeparator()
            SettingsToggleRow(title: "Weekly summary", symbol: "calendar", isOn: $weeklySummary)
            SettingsSeparator()
            SettingsToggleRow(title: "Restock alerts", symbol: "shippingbox", isOn: $restockAlerts)
            SettingsSeparator()
            // Dummy value (owner, 2026-11-15); display only.
            SettingsRow(title: "Quiet hours", symbol: "moon", value: "10 PM – 8 AM")
        }
    }

    // Appearance and language are display only: the app is dark-only and English-only.
    private var appSection: some View {
        SettingsSection(title: "App") {
            SettingsRow(title: "Appearance", symbol: "circle.lefthalf.filled", value: "Dark")
            SettingsSeparator()
            SettingsToggleRow(title: "Haptics", symbol: "iphone.radiowaves.left.and.right", isOn: $haptics)
            SettingsSeparator()
            SettingsRow(title: "Shortcut", symbol: "plus.circle")
            SettingsSeparator()
            SettingsRow(title: "Back Tap", symbol: "hand.tap")
            SettingsSeparator()
            SettingsRow(title: "App language", symbol: "textformat", value: "English")
        }
    }

    private var aboutSection: some View {
        SettingsSection(title: "About") {
            SettingsRow(title: "Privacy policy", symbol: "hand.raised")
            SettingsSeparator()
            SettingsRow(title: "Terms of service", symbol: "doc.text")
            SettingsSeparator()
            SettingsRow(title: "Version", symbol: "info.circle", value: Self.version)
        }
    }

    // Sign out does nothing yet (there are no accounts), so it is a plain row, not a button.
    private var signOut: some View {
        SettingsSection {
            Text("Sign out")
                .textStyle(.body)
                .foregroundStyle(Palette.danger)
                .frame(maxWidth: .infinity, minHeight: SettingsMetrics.rowHeight)
        }
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}

// Where the Settings choices are kept on the device.
enum SettingsKeys {
    static let region = "settingsRegion"
    static let currency = "settingsCurrency"
    static let stores = "settingsPreferredStores"
    static let dropThreshold = "settingsDropThreshold"
    static let priceDrops = "settingsNotifyPriceDrops"
    static let weeklySummary = "settingsNotifyWeeklySummary"
    static let restockAlerts = "settingsNotifyRestock"
    static let haptics = "settingsHaptics"
}

// The choices each list offers; the first region and currency are the defaults.
enum SettingsOptions {
    static let regions = ["United States", "Canada", "United Kingdom", "Australia"]
    static let currencies = ["USD", "CAD", "GBP", "EUR", "AUD"]
    static let stores = ["Amazon", "Best Buy", "Target", "Walmart", "Costco", "Apple", "eBay"]
    static let defaultStores = "Amazon,Best Buy,Target"
    static let dropThresholds = [5, 10, 15, 20]
}

// Preferred stores are kept as one comma-separated string, since @AppStorage has no list type.
enum StoreList {
    static func names(_ stored: String) -> [String] {
        stored.split(separator: ",").map(String.init)
    }

    static func contains(_ stored: String, _ store: String) -> Bool {
        names(stored).contains(store)
    }

    // Adds or removes the store, keeping the order of SettingsOptions.stores.
    static func toggling(_ stored: String, _ store: String) -> String {
        var chosen = Set(names(stored))
        if chosen.contains(store) { chosen.remove(store) } else { chosen.insert(store) }
        return SettingsOptions.stores.filter(chosen.contains).joined(separator: ",")
    }

    static func summary(_ stored: String) -> String {
        let count = names(stored).count
        return count == 1 ? "1 store" : "\(count) stores"
    }
}

// The dummy persona's profile photo, a royalty-free Unsplash portrait (see the 2026-11-15
// settings change note for the source).
struct ProfilePhoto: View {
    var size: CGFloat = 56

    var body: some View {
        Image("ProfilePhoto")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay { Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1) }
            .accessibilityHidden(true)
    }
}

// Where the profile fields are kept on the device. Nothing is sent anywhere.
enum ProfileKeys {
    static let name = "profileName"
    static let handle = "profileHandle"
    static let bio = "profileBio"
    static let email = "profileEmail"
}

// Dummy defaults for a fictional persona (owner, 2026-11-15), shown until the user sets their own.
enum ProfileDefaults {
    static let name = "Alex Rivera"
    static let email = "alex.rivera@example.com"
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
