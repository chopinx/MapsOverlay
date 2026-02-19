import XCTest
@testable import MapOverlay

final class SavedPinTests: XCTestCase {

    // MARK: - Codable round-trip

    func test_encodeDecode_roundTrip_preservesAllFields() throws {
        let pin = SavedPin(name: "Home", latitude: 52.52, longitude: 13.405)

        let data = try JSONEncoder().encode(pin)
        let decoded = try JSONDecoder().decode(SavedPin.self, from: data)

        XCTAssertEqual(decoded.id, pin.id)
        XCTAssertEqual(decoded.name, "Home")
        XCTAssertEqual(decoded.latitude, 52.52)
        XCTAssertEqual(decoded.longitude, 13.405)
    }

    // MARK: - Init

    func test_init_setsUniqueId() {
        let pin1 = SavedPin(name: "A", latitude: 0, longitude: 0)
        let pin2 = SavedPin(name: "B", latitude: 0, longitude: 0)
        XCTAssertNotEqual(pin1.id, pin2.id)
    }

    func test_init_setsCreatedAt() {
        let before = Date()
        let pin = SavedPin(name: "Test", latitude: 1.0, longitude: 2.0)
        let after = Date()

        XCTAssertGreaterThanOrEqual(pin.createdAt, before)
        XCTAssertLessThanOrEqual(pin.createdAt, after)
    }
}
