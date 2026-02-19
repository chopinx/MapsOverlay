import XCTest
import CoreLocation
@testable import MapOverlay

@MainActor
final class MapOverlayViewModelTests: XCTestCase {

    private var tempDir: URL!
    private var viewModel: MapOverlayViewModel!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("VMTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let overlayDir = tempDir.appendingPathComponent("overlays", isDirectory: true)
        try? FileManager.default.createDirectory(at: overlayDir, withIntermediateDirectories: true)
        let overlayStore = OverlayStore(directory: overlayDir)

        let pinURL = tempDir.appendingPathComponent("pins.json")
        let pinStore = PinStore(storeURL: pinURL)

        viewModel = MapOverlayViewModel(
            store: overlayStore,
            pinStore: pinStore
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        viewModel = nil
        tempDir = nil
        super.tearDown()
    }

    // MARK: - removeOverlay

    func test_removeOverlay_resetsAllState() {
        viewModel.selectedImage = makeTestImage()
        viewModel.opacity = 0.8
        viewModel.rotation = 45.0
        viewModel.isLocked = true
        viewModel.isTransformMode = true
        viewModel.transformCorners = FreeTransformCorners(
            topLeft: CGPoint(x: 0.1, y: 0.1),
            topRight: CGPoint(x: 0.9, y: 0.1),
            bottomLeft: CGPoint(x: 0.1, y: 0.9),
            bottomRight: CGPoint(x: 0.9, y: 0.9)
        )
        viewModel.lockedNorthEast = CLLocationCoordinate2D(latitude: 40, longitude: -73)
        viewModel.lockedSouthWest = CLLocationCoordinate2D(latitude: 39, longitude: -74)

        viewModel.removeOverlay()

        XCTAssertNil(viewModel.selectedImage)
        XCTAssertFalse(viewModel.isLocked)
        XCTAssertFalse(viewModel.isTransformMode)
        XCTAssertTrue(viewModel.transformCorners.isIdentity)
        XCTAssertEqual(viewModel.opacity, 0.5)
        XCTAssertEqual(viewModel.rotation, 0)
        XCTAssertNil(viewModel.lockedNorthEast)
        XCTAssertNil(viewModel.lockedSouthWest)
    }

    // MARK: - unlockOverlay

    func test_unlockOverlay_setsIsLockedFalse() {
        viewModel.isLocked = true
        viewModel.unlockOverlay()
        XCTAssertFalse(viewModel.isLocked)
    }

    // MARK: - Pin management

    func test_addPin_appendsPin() {
        let coord = CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405)
        viewModel.addPin(name: "Berlin", coordinate: coord)

        XCTAssertEqual(viewModel.savedPins.count, 1)
        XCTAssertEqual(viewModel.savedPins.first?.name, "Berlin")
        XCTAssertEqual(viewModel.savedPins.first?.latitude, 52.52)
        XCTAssertEqual(viewModel.savedPins.first?.longitude, 13.405)
    }

    func test_deletePin_removesMatchingPin() {
        let coord = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        viewModel.addPin(name: "A", coordinate: coord)
        viewModel.addPin(name: "B", coordinate: coord)

        let pinToDelete = viewModel.savedPins[0]
        viewModel.deletePin(pinToDelete)

        XCTAssertEqual(viewModel.savedPins.count, 1)
        XCTAssertEqual(viewModel.savedPins.first?.name, "B")
    }

    func test_clearAllPins_removesAllPins() {
        let coord = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        viewModel.addPin(name: "A", coordinate: coord)
        viewModel.addPin(name: "B", coordinate: coord)
        viewModel.addPin(name: "C", coordinate: coord)

        viewModel.clearAllPins()

        XCTAssertTrue(viewModel.savedPins.isEmpty)
    }

    // MARK: - toggleTransformMode

    func test_toggleTransformMode_togglesValue() {
        XCTAssertFalse(viewModel.isTransformMode)
        viewModel.toggleTransformMode()
        XCTAssertTrue(viewModel.isTransformMode)
        viewModel.toggleTransformMode()
        XCTAssertFalse(viewModel.isTransformMode)
    }

    // MARK: - resetTransform

    func test_resetTransform_setsIdentityCorners() {
        viewModel.transformCorners = FreeTransformCorners(
            topLeft: CGPoint(x: 0.2, y: 0.2),
            topRight: CGPoint(x: 0.8, y: 0.2),
            bottomLeft: CGPoint(x: 0.2, y: 0.8),
            bottomRight: CGPoint(x: 0.8, y: 0.8)
        )
        viewModel.resetTransform()
        XCTAssertTrue(viewModel.transformCorners.isIdentity)
    }

    // MARK: - Helper

    private func makeTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        return renderer.image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
    }
}
