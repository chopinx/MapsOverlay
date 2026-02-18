import SwiftUI

struct SettingsView: View {
    @ObservedObject var authService: GoogleAuthService
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = Config.googleMapsAPIKey
    @State private var showingRestartAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Google Maps API Key", text: $apiKey)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Google Maps")
                } footer: {
                    Text("Get an API key from the Google Cloud Console. The app needs to restart after changing this.")
                }

                Section("Google Account") {
                    if authService.isSignedIn, let user = authService.currentUser {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(user.profile?.name ?? "Signed in")
                                    .font(.body)
                                if let email = user.profile?.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button("Sign Out", role: .destructive) {
                                authService.signOut()
                            }
                        }
                    } else {
                        Button {
                            authService.signIn()
                        } label: {
                            HStack {
                                Image(systemName: "person.circle")
                                Text("Sign in with Google")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed != Config.googleMapsAPIKey {
                            Config.googleMapsAPIKey = trimmed
                            showingRestartAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Restart Required", isPresented: $showingRestartAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("Please restart the app for the new API key to take effect.")
            }
        }
    }
}
