import Foundation
import GoogleSignIn

@MainActor
final class GoogleAuthService: ObservableObject {
    @Published var currentUser: GIDGoogleUser?
    @Published var isSignedIn = false

    init() {
        restorePreviousSignIn()
    }

    func signIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController
        else { return }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                guard error == nil, let user = result?.user else { return }
                self?.updateUser(user)
            }
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        updateUser(nil)
    }

    private func restorePreviousSignIn() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            DispatchQueue.main.async {
                guard error == nil, let user else { return }
                self?.updateUser(user)
            }
        }
    }

    private func updateUser(_ user: GIDGoogleUser?) {
        currentUser = user
        isSignedIn = user != nil
    }
}
