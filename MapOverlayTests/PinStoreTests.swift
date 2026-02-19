import XCTest
@testable import MapOverlay

final class PinStoreTests: XCTestCase {

    private var tempDir: URL!
    private var store: PinStore!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PinStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let storeURL = tempDir.appendingPathComponent("saved_pins.json")
        store = PinStore(storeURL: storeURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        store = nil
        tempDir = nil
        super.tearDown()
    }

    // MARK: - Save / Load cycle

    func test_saveAndLoad_roundTrip_returnsPins() throws {
        let pins = [
            SavedPin(name: "Home", latitude: 52.52, longitude: 13.405),
            SavedPin(name: "Work", latitude: 48.85, longitude: 2.35),
        ]

        try store.save(pins)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].name, "Home")
        XCTAssertEqual(loaded[1].name, "Work")
        XCTAssertEqual(loaded[0].id, pins[0].id)
        XCTAssertEqual(loaded[1].id, pins[1].id)
    }

    func test_loadAll_emptyStore_returnsEmptyArray() {
        XCTAssertEqual(store.loadAll().count, 0)
    }

    func test_save_emptyArray_clearsPins() throws {
        let pins = [SavedPin(name: "Test", latitude: 0, longitude: 0)]
        try store.save(pins)
        XCTAssertEqual(store.loadAll().count, 1)

        try store.save([])
        XCTAssertEqual(store.loadAll().count, 0)
    }

    // MARK: - Error-tolerant decoding

    func test_loadAll_corruptEntry_skipsCorruptAndReturnsValid() throws {
        let validPin = SavedPin(name: "Valid", latitude: 1.0, longitude: 2.0)
        let validData = try JSONEncoder().encode(validPin)
        let validDict = try JSONSerialization.jsonObject(with: validData) as! [String: Any]

        let corruptDict: [String: Any] = ["id": "not-a-uuid", "bad": 42]
        let array = [validDict, corruptDict]
        let arrayData = try JSONSerialization.data(withJSONObject: array)

        let fileURL = tempDir.appendingPathComponent("saved_pins.json")
        try arrayData.write(to: fileURL)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1, "Should skip corrupt entries")
        XCTAssertEqual(loaded.first?.name, "Valid")
    }
}
