import XCTest
@testable import MapOverlay

final class FreeTransformCornersTests: XCTestCase {

    // MARK: - Identity

    func test_identity_hasExpectedValues() {
        let identity = FreeTransformCorners.identity
        XCTAssertEqual(identity.topLeft, CGPoint(x: 0, y: 0))
        XCTAssertEqual(identity.topRight, CGPoint(x: 1, y: 0))
        XCTAssertEqual(identity.bottomLeft, CGPoint(x: 0, y: 1))
        XCTAssertEqual(identity.bottomRight, CGPoint(x: 1, y: 1))
    }

    func test_isIdentity_forIdentityCorners_returnsTrue() {
        XCTAssertTrue(FreeTransformCorners.identity.isIdentity)
    }

    func test_isIdentity_forModifiedCorners_returnsFalse() {
        var corners = FreeTransformCorners.identity
        corners.topLeft = CGPoint(x: 0.1, y: 0.1)
        XCTAssertFalse(corners.isIdentity)
    }

    // MARK: - Equatable

    func test_equatable_identicalCorners_areEqual() {
        let a = FreeTransformCorners(
            topLeft: CGPoint(x: 0.1, y: 0.2),
            topRight: CGPoint(x: 0.8, y: 0.2),
            bottomLeft: CGPoint(x: 0.1, y: 0.9),
            bottomRight: CGPoint(x: 0.8, y: 0.9)
        )
        let b = FreeTransformCorners(
            topLeft: CGPoint(x: 0.1, y: 0.2),
            topRight: CGPoint(x: 0.8, y: 0.2),
            bottomLeft: CGPoint(x: 0.1, y: 0.9),
            bottomRight: CGPoint(x: 0.8, y: 0.9)
        )
        XCTAssertEqual(a, b)
    }

    func test_equatable_differentCorners_areNotEqual() {
        let a = FreeTransformCorners.identity
        var b = FreeTransformCorners.identity
        b.bottomRight = CGPoint(x: 0.5, y: 0.5)
        XCTAssertNotEqual(a, b)
    }
}
