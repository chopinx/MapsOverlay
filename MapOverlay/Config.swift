import Foundation

enum Config {
    static let googleClientID = "773104774563-nddqjsm0ljrghkjp403vu7evaum0sk7d.apps.googleusercontent.com"

    private static let apiKeyKey = "google_maps_api_key"

    static var googleMapsAPIKey: String {
        get { UserDefaults.standard.string(forKey: apiKeyKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: apiKeyKey) }
    }

    static var hasAPIKey: Bool {
        !googleMapsAPIKey.isEmpty
    }
}
