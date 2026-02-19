import SwiftUI
import GoogleSignInSwift

struct SignInView: View {
    @ObservedObject var authService: GoogleAuthService

    var body: some View {
        if authService.isSignedIn {
            Menu {
                if let user = authService.currentUser {
                    Text(user.profile?.email ?? "Signed in")
                }
                Button("Sign Out", role: .destructive) {
                    authService.signOut()
                }
            } label: {
                profileButton(icon: "person.circle.fill", color: .blue)
            }
            .accessibilityLabel("Google account")
        } else {
            Button {
                authService.signIn()
            } label: {
                profileButton(icon: "person.circle", color: .primary)
            }
            .accessibilityLabel("Sign in with Google")
        }
    }

    private func profileButton(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.body)
            .foregroundColor(color)
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}
