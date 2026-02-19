import XCTest
@testable import MapOverlay

final class OverlayStoreTests: XCTestCase {

    private var tempDir: URL!
    private var store: OverlayStore!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OverlayStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = OverlayStore(directory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        store = nil
        tempDir = nil
        super.tearDown()
    }

    // MARK: - Save / Load / Delete cycle

    func test_saveAndLoad_roundTrip_returnsOverlay() throws {
        let image = makeTestImage()
        let saved = try store.saveOverlay(
            image: image,
            name: "Test",
            northEastLatitude: 40.0,
            northEastLongitude: -73.0,
            southWestLatitude: 39.0,
            southWestLongitude: -74.0,
            opacity: 0.8,
            rotation: 15.0
        )

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, saved.id)
        XCTAssertEqual(loaded.first?.name, "Test")
        XCTAssertEqual(loaded.first?.rotation, 15.0)
    }

    func test_delete_removesOverlay() throws {
        let image = makeTestImage()
        let saved = try store.saveOverlay(
            image: image,
            name: "ToDelete",
            northEastLatitude: 1, northEastLongitude: 2,
            southWestLatitude: 3, southWestLongitude: 4,
            opacity: 0.5
        )

        XCTAssertEqual(store.loadAll().count, 1)
        try store.delete(saved)
        XCTAssertEqual(store.loadAll().count, 0)
    }

    func test_loadAll_emptyStore_returnsEmptyArray() {
        XCTAssertEqual(store.loadAll().count, 0)
    }

    func test_saveMultipleOverlays_loadsAll() throws {
        let image = makeTestImage()
        _ = try store.saveOverlay(image: image, name: "A", northEastLatitude: 1, northEastLongitude: 2, southWestLatitude: 3, southWestLongitude: 4, opacity: 0.5)
        _ = try store.saveOverlay(image: image, name: "B", northEastLatitude: 5, northEastLongitude: 6, southWestLatitude: 7, southWestLongitude: 8, opacity: 0.6)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.map(\.name), ["A", "B"])
    }

    // MARK: - Error-tolerant decoding

    func test_loadAll_corruptEntry_skipsCorruptAndReturnsValid() throws {
        let validOverlay = SavedOverlay(
            name: "Valid",
            imagePath: "v.png",
            northEastLatitude: 1, northEastLongitude: 2,
            southWestLatitude: 3, southWestLongitude: 4,
            opacity: 0.5
        )
        let validData = try JSONEncoder().encode(validOverlay)
        let validDict = try JSONSerialization.jsonObject(with: validData) as! [String: Any]

        let corruptDict: [String: Any] = ["id": "not-a-uuid", "garbage": true]
        let array = [validDict, corruptDict]
        let arrayData = try JSONSerialization.data(withJSONObject: array)

        let metadataURL = tempDir.appendingPathComponent("metadata.json")
        try arrayData.write(to: metadataURL)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1, "Should skip corrupt entries and load valid ones")
        XCTAssertEqual(loaded.first?.name, "Valid")
    }

    // MARK: - Backup on save

    func test_save_createsBackupFile() throws {
        let image = makeTestImage()
        _ = try store.saveOverlay(
            image: image, name: "First",
            northEastLatitude: 1, northEastLongitude: 2,
            southWestLatitude: 3, southWestLongitude: 4,
            opacity: 0.5
        )
        _ = try store.saveOverlay(
            image: image, name: "Second",
            northEastLatitude: 5, northEastLongitude: 6,
            southWestLatitude: 7, southWestLongitude: 8,
            opacity: 0.6
        )

        let backupURL = tempDir.appendingPathComponent("metadata.backup.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path), "Backup file should exist after second save")

        let backupData = try Data(contentsOf: backupURL)
        let backupOverlays = try JSONDecoder().decode([SavedOverlay].self, from: backupData)
        XCTAssertEqual(backupOverlays.count, 1)
        XCTAssertEqual(backupOverlays.first?.name, "First")
    }

    // MARK: - Load image

    func test_loadImage_afterSave_returnsImage() throws {
        let image = makeTestImage()
        let saved = try store.saveOverlay(
            image: image, name: "Img",
            northEastLatitude: 1, northEastLongitude: 2,
            southWestLatitude: 3, southWestLongitude: 4,
            opacity: 0.5
        )

        let loaded = store.loadImage(for: saved)
        XCTAssertNotNil(loaded, "Should be able to load image after saving")
    }

    // MARK: - Helper

    private func makeTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
    }
}
