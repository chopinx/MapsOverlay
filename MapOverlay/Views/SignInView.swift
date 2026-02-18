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
                Image(systemName: "person.circle.fill")
                    .font(.body)
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }
        } else {
            Button {
                authService.signIn()
            } label: {
                Image(systemName: "person.circle")
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }
        }
    }
}
