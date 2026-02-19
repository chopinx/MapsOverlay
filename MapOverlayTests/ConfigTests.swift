import XCTest
@testable import MapOverlay

final class ConfigTests: XCTestCase {

    // MARK: - isValidAPIKeyFormat

    func test_isValidAPIKeyFormat_validKey_returnsTrue() {
        // Build a valid-format key programmatically to avoid secret detection
        let prefix = "AIza"
        let suffix = String(repeating: "T", count: 35)
        XCTAssertTrue(Config.isValidAPIKeyFormat(prefix + suffix))
    }

    func test_isValidAPIKeyFormat_validKeyWithDashAndUnderscore_returnsTrue() {
        // AIza (4) + 35 alphanumeric/dash/underscore = 39
        let key = "AIza" + "01234-6789_bcdefghijklmnopqrstuvwxy"
        XCTAssertEqual(key.count, 39)
        XCTAssertTrue(Config.isValidAPIKeyFormat(key))
    }

    func test_isValidAPIKeyFormat_missingPrefix_returnsFalse() {
        let key = "XXXX" + String(repeating: "a", count: 35)
        XCTAssertFalse(Config.isValidAPIKeyFormat(key))
    }

    func test_isValidAPIKeyFormat_tooShort_returnsFalse() {
        let key = "AIzaShort"
        XCTAssertFalse(Config.isValidAPIKeyFormat(key))
    }

    func test_isValidAPIKeyFormat_tooLong_returnsFalse() {
        let key = "AIza" + String(repeating: "a", count: 36)
        XCTAssertFalse(Config.isValidAPIKeyFormat(key))
    }

    func test_isValidAPIKeyFormat_emptyString_returnsFalse() {
        XCTAssertFalse(Config.isValidAPIKeyFormat(""))
    }

    func test_isValidAPIKeyFormat_invalidCharacters_returnsFalse() {
        let key = "AIza" + "!@#$%^&*()" + String(repeating: "x", count: 25)
        XCTAssertFalse(Config.isValidAPIKeyFormat(key))
    }

    func test_isValidAPIKeyFormat_exactLength39_returnsTrue() {
        // AIza = 4 chars + 35 chars = 39 total
        let suffix = String(repeating: "A", count: 35)
        let key = "AIza" + suffix
        XCTAssertEqual(key.count, 39)
        XCTAssertTrue(Config.isValidAPIKeyFormat(key))
    }
}
