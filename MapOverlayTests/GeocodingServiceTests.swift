import XCTest
@testable import MapOverlay

final class GeocodingServiceTests: XCTestCase {

    func test_geocodingService_initializes() {
        let service = GeocodingService()
        XCTAssertNotNil(service)
    }
}
