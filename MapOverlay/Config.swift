import Foundation
import Security

enum Config {
    // Google considers mobile OAuth client IDs public — they rely on app signing, not secrecy.
    static let googleClientID = "773104774563-nddqjsm0ljrghkjp403vu7evaum0sk7d.apps.googleusercontent.com"
    static let nominatimUserAgent = "MapOverlay/1.0 (https://github.com/chopinx/MapsOverlay)"

    private static let apiKeyService = "com.mapoverlay.google-maps-api-key"
    private static let apiKeyAccount = "google_maps_api_key"

    static var googleMapsAPIKey: String {
        get { keychainRead(service: apiKeyService, account: apiKeyAccount) ?? "" }
        set {
            if newValue.isEmpty {
                keychainDelete(service: apiKeyService, account: apiKeyAccount)
            } else {
                keychainWrite(service: apiKeyService, account: apiKeyAccount, value: newValue)
            }
        }
    }

    static var hasAPIKey: Bool {
        !googleMapsAPIKey.isEmpty
    }

    /// Validates whether a string looks like a Google Maps API key.
    /// Expected format: `AIza` followed by 35 alphanumeric/dash/underscore characters (39 total).
    static func isValidAPIKeyFormat(_ key: String) -> Bool {
        let pattern = #"^AIza[0-9A-Za-z_-]{35}$"#
        return key.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Keychain Helpers

    private static func keychainRead(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func keychainWrite(service: String, account: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Try to update first
        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Item doesn't exist yet, add it
            var addQuery = searchQuery
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private static func keychainDelete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
