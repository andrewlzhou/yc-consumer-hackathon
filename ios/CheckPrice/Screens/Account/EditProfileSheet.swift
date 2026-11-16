// Edit profile: name, handle and bio, kept on the device. Changes apply on Done; Cancel drops them.
import SwiftUI

struct EditProfileSheet: View {
    @AppStorage(ProfileKeys.name) private var name = ""
    @AppStorage(ProfileKeys.handle) private var handle = ""
    @AppStorage(ProfileKeys.bio) private var bio = ""
    @State private var draftName = ""
    @State private var draftHandle = ""
    @State private var draftBio = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.betweenFields) {
                    ProfileAvatar(name: draftName, size: 72)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 6)
                    OutlinedField("Name", prompt: "Your name", text: $draftName)
                        .textContentType(.name)
                    OutlinedField("Handle", prompt: "yourhandle", text: $draftHandle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                    OutlinedField("Bio", prompt: "A line about you", text: $draftBio)
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Cancel").textStyle(.body) }
                        .tint(Palette.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { Text("Done").textStyle(.button) }
                        .tint(Palette.accent)
                }
            }
        }
        .onAppear {
            draftName = name
            draftHandle = handle
            draftBio = bio
        }
    }

    private func save() {
        name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        handle = Self.cleanHandle(draftHandle)
        bio = draftBio.trimmingCharacters(in: .whitespacesAndNewlines)
        dismiss()
    }

    // Handles are lowercase with no spaces or leading @, as on Instagram.
    static func cleanHandle(_ text: String) -> String {
        String(text.lowercased().filter { !$0.isWhitespace && $0 != "@" })
    }
}
