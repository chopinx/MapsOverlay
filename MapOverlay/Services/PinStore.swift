import Foundation

final class PinStore {
    private let fileManager = FileManager.default

    private var storeURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("saved_pins.json")
    }

    func loadAll() -> [SavedPin] {
        guard let data = try? Data(contentsOf: storeURL) else { return [] }
        // Try full array decode first
        if let pins = try? JSONDecoder().decode([SavedPin].self, from: data) {
            return pins
        }
        // Error-tolerant: skip corrupt entries
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return jsonArray.compactMap { dict in
            guard let entryData = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
            return try? JSONDecoder().decode(SavedPin.self, from: entryData)
        }
    }

    func save(_ pins: [SavedPin]) throws {
        let data = try JSONEncoder().encode(pins)
        try data.write(to: storeURL, options: .atomic)
    }
}
