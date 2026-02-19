import SwiftUI
import GoogleMaps
import GoogleSignIn

@main
struct MapOverlayApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if Config.hasAPIKey {
            let key = Config.googleMapsAPIKey
            if !Config.isValidAPIKeyFormat(key) {
                print("[MapOverlay] Warning: API key does not match expected Google Maps format (AIza...39 chars). Attempting to use it anyway.")
            }
            GMSServices.provideAPIKey(key)
        }
        if !Config.googleClientID.isEmpty {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: Config.googleClientID)
        }
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
