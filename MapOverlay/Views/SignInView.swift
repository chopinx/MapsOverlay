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
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        } else {
            Button {
                authService.signIn()
            } label: {
                Image(systemName: "person.circle")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
    }
}
