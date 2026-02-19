import XCTest
@testable import MapOverlay

final class SavedOverlayTests: XCTestCase {

    // MARK: - Codable round-trip

    func test_encodeDecode_roundTrip_preservesAllFields() throws {
        let overlay = SavedOverlay(
            name: "Test Overlay",
            imagePath: "test.png",
            northEastLatitude: 40.0,
            northEastLongitude: -73.0,
            southWestLatitude: 39.0,
            southWestLongitude: -74.0,
            opacity: 0.7,
            rotation: 45.0
        )

        let data = try JSONEncoder().encode(overlay)
        let decoded = try JSONDecoder().decode(SavedOverlay.self, from: data)

        XCTAssertEqual(decoded.id, overlay.id)
        XCTAssertEqual(decoded.name, "Test Overlay")
        XCTAssertEqual(decoded.imagePath, "test.png")
        XCTAssertEqual(decoded.northEastLatitude, 40.0)
        XCTAssertEqual(decoded.northEastLongitude, -73.0)
        XCTAssertEqual(decoded.southWestLatitude, 39.0)
        XCTAssertEqual(decoded.southWestLongitude, -74.0)
        XCTAssertEqual(decoded.opacity, 0.7)
        XCTAssertEqual(decoded.rotation, 45.0)
    }

    // MARK: - Backward compatibility (missing rotation)

    func test_decode_missingRotation_defaultsToZero() throws {
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "name": "Legacy",
            "imagePath": "old.png",
            "northEastLatitude": 40.0,
            "northEastLongitude": -73.0,
            "southWestLatitude": 39.0,
            "southWestLongitude": -74.0,
            "opacity": 0.5,
            "createdAt": 0
        }
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(SavedOverlay.self, from: data)

        XCTAssertEqual(decoded.rotation, 0, "Missing rotation field should default to 0")
        XCTAssertEqual(decoded.name, "Legacy")
    }

    // MARK: - Init defaults

    func test_init_defaultRotation_isZero() {
        let overlay = SavedOverlay(
            name: "Default",
            imagePath: "img.png",
            northEastLatitude: 1.0,
            northEastLongitude: 2.0,
            southWestLatitude: 3.0,
            southWestLongitude: 4.0,
            opacity: 0.5
        )
        XCTAssertEqual(overlay.rotation, 0)
    }
}
