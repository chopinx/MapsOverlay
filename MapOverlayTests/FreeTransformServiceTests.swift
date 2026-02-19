import XCTest
import SwiftUI
@testable import MapOverlay

final class FreeTransformServiceTests: XCTestCase {

    private var service: FreeTransformService!

    override func setUp() {
        super.setUp()
        service = FreeTransformService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - projectionTransform

    func test_projectionTransform_identityCorners_producesIdentityTransform() {
        let size = CGSize(width: 200, height: 200)
        let transform = service.projectionTransform(for: .identity, in: size)
        let identity = ProjectionTransform(.identity)

        // For identity corners the homography should map each point to itself.
        // Check key matrix elements are close to identity.
        XCTAssertEqual(transform.m11, identity.m11, accuracy: 1e-6)
        XCTAssertEqual(transform.m22, identity.m22, accuracy: 1e-6)
        XCTAssertEqual(transform.m33, identity.m33, accuracy: 1e-6)
        XCTAssertEqual(transform.m13, 0, accuracy: 1e-6, "g should be 0 for identity")
        XCTAssertEqual(transform.m23, 0, accuracy: 1e-6, "h should be 0 for identity")
    }

    func test_projectionTransform_nonIdentityCorners_producesNonIdentityTransform() {
        let corners = FreeTransformCorners(
            topLeft: CGPoint(x: 0.1, y: 0.1),
            topRight: CGPoint(x: 0.9, y: 0.05),
            bottomLeft: CGPoint(x: 0.05, y: 0.95),
            bottomRight: CGPoint(x: 0.85, y: 0.9)
        )
        let size = CGSize(width: 300, height: 400)
        let transform = service.projectionTransform(for: corners, in: size)
        let identity = ProjectionTransform(.identity)

        // At least one element should differ from identity
        let isIdentity = (
            abs(transform.m11 - identity.m11) < 1e-6 &&
            abs(transform.m12 - identity.m12) < 1e-6 &&
            abs(transform.m21 - identity.m21) < 1e-6 &&
            abs(transform.m22 - identity.m22) < 1e-6 &&
            abs(transform.m31 - identity.m31) < 1e-6 &&
            abs(transform.m32 - identity.m32) < 1e-6
        )
        XCTAssertFalse(isIdentity, "Non-identity corners should produce a non-identity transform")
    }

    func test_projectionTransform_zeroSize_returnsIdentity() {
        let transform = service.projectionTransform(for: .identity, in: .zero)
        let identity = ProjectionTransform(.identity)
        XCTAssertEqual(transform.m11, identity.m11, accuracy: 1e-6)
        XCTAssertEqual(transform.m22, identity.m22, accuracy: 1e-6)
        XCTAssertEqual(transform.m33, identity.m33, accuracy: 1e-6)
    }

    // MARK: - bakeTransform

    func test_bakeTransform_identityCorners_returnsOriginalImage() {
        let image = makeTestImage()
        let result = service.bakeTransform(image: image, corners: .identity)
        // When corners are identity, bakeTransform returns the original image
        XCTAssertNotNil(result)
        XCTAssertEqual(result, image, "Identity corners should return the same image object")
    }

    func test_bakeTransform_nonIdentityCorners_returnsTransformedImage() {
        let image = makeTestImage()
        let corners = FreeTransformCorners(
            topLeft: CGPoint(x: 0.1, y: 0.1),
            topRight: CGPoint(x: 0.9, y: 0.1),
            bottomLeft: CGPoint(x: 0.1, y: 0.9),
            bottomRight: CGPoint(x: 0.9, y: 0.9)
        )
        let result = service.bakeTransform(image: image, corners: corners)
        XCTAssertNotNil(result, "Should return a baked image for non-identity corners")
    }

    // MARK: - Helper

    private func makeTestImage(width: Int = 100, height: Int = 100) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
