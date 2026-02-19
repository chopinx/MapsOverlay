import XCTest
import CoreLocation
@testable import MapOverlay

final class BoundaryServiceTests: XCTestCase {

    // MARK: - BoundaryError

    func test_boundaryError_parseError_exists() {
        let error = BoundaryError.parseError
        XCTAssertNotNil(error)
    }

    func test_boundaryError_noResults_exists() {
        let error = BoundaryError.noResults
        XCTAssertNotNil(error)
    }

    func test_boundaryError_networkError_wrapsUnderlying() {
        let underlying = URLError(.notConnectedToInternet)
        let error = BoundaryError.networkError(underlying: underlying)
        if case .networkError(let wrapped) = error {
            XCTAssertTrue(wrapped is URLError)
        } else {
            XCTFail("Expected networkError case")
        }
    }

    // MARK: - PlaceBoundary Equatable

    func test_placeBoundary_equalToItself() {
        let polygon = BoundaryPolygon(
            outer: [
                CLLocationCoordinate2D(latitude: 0, longitude: 0),
                CLLocationCoordinate2D(latitude: 1, longitude: 0),
                CLLocationCoordinate2D(latitude: 1, longitude: 1),
                CLLocationCoordinate2D(latitude: 0, longitude: 0),
            ],
            holes: []
        )
        let boundary = PlaceBoundary(polygons: [polygon])
        XCTAssertEqual(boundary, boundary)
    }

    func test_placeBoundary_samePolygons_areEqual() {
        let polygon = BoundaryPolygon(
            outer: [
                CLLocationCoordinate2D(latitude: 0, longitude: 0),
                CLLocationCoordinate2D(latitude: 1, longitude: 0),
                CLLocationCoordinate2D(latitude: 1, longitude: 1),
                CLLocationCoordinate2D(latitude: 0, longitude: 0),
            ],
            holes: []
        )
        let a = PlaceBoundary(polygons: [polygon])
        let b = PlaceBoundary(polygons: [polygon])
        // PlaceBoundary == compares by polygons content
        XCTAssertEqual(a, b)
    }

    func test_placeBoundary_differentPolygons_notEqual() {
        let polyA = BoundaryPolygon(
            outer: [
                CLLocationCoordinate2D(latitude: 0, longitude: 0),
                CLLocationCoordinate2D(latitude: 1, longitude: 0),
                CLLocationCoordinate2D(latitude: 1, longitude: 1),
                CLLocationCoordinate2D(latitude: 0, longitude: 0),
            ],
            holes: []
        )
        let polyB = BoundaryPolygon(
            outer: [
                CLLocationCoordinate2D(latitude: 10, longitude: 10),
                CLLocationCoordinate2D(latitude: 11, longitude: 10),
                CLLocationCoordinate2D(latitude: 11, longitude: 11),
                CLLocationCoordinate2D(latitude: 10, longitude: 10),
            ],
            holes: []
        )
        let a = PlaceBoundary(polygons: [polyA])
        let b = PlaceBoundary(polygons: [polyB])
        XCTAssertNotEqual(a, b)
    }

    // MARK: - BoundaryPolygon Equatable

    func test_boundaryPolygon_sameCoordinates_areEqual() {
        let coords = [
            CLLocationCoordinate2D(latitude: 10, longitude: 20),
            CLLocationCoordinate2D(latitude: 30, longitude: 40),
            CLLocationCoordinate2D(latitude: 50, longitude: 60),
            CLLocationCoordinate2D(latitude: 10, longitude: 20),
        ]
        let a = BoundaryPolygon(outer: coords, holes: [])
        let b = BoundaryPolygon(outer: coords, holes: [])
        XCTAssertEqual(a, b)
    }

    func test_boundaryPolygon_differentCoordinates_areNotEqual() {
        let coordsA = [
            CLLocationCoordinate2D(latitude: 10, longitude: 20),
            CLLocationCoordinate2D(latitude: 30, longitude: 40),
            CLLocationCoordinate2D(latitude: 50, longitude: 60),
            CLLocationCoordinate2D(latitude: 10, longitude: 20),
        ]
        let coordsB = [
            CLLocationCoordinate2D(latitude: 99, longitude: 99),
            CLLocationCoordinate2D(latitude: 30, longitude: 40),
            CLLocationCoordinate2D(latitude: 50, longitude: 60),
            CLLocationCoordinate2D(latitude: 99, longitude: 99),
        ]
        let a = BoundaryPolygon(outer: coordsA, holes: [])
        let b = BoundaryPolygon(outer: coordsB, holes: [])
        XCTAssertNotEqual(a, b)
    }

    func test_boundaryPolygon_differentHoles_areNotEqual() {
        let outer = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
        ]
        let holeA = [
            CLLocationCoordinate2D(latitude: 0.2, longitude: 0.2),
            CLLocationCoordinate2D(latitude: 0.3, longitude: 0.2),
            CLLocationCoordinate2D(latitude: 0.3, longitude: 0.3),
            CLLocationCoordinate2D(latitude: 0.2, longitude: 0.2),
        ]
        let a = BoundaryPolygon(outer: outer, holes: [holeA])
        let b = BoundaryPolygon(outer: outer, holes: [])
        XCTAssertNotEqual(a, b)
    }

    // MARK: - BoundaryService init

    func test_boundaryService_initializes() {
        let service = BoundaryService()
        XCTAssertNotNil(service)
    }
}
