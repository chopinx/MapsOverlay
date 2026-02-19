import Foundation

final class PinStore {
    private let fileManager = FileManager.default

    private var storeURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("saved_pins.json")
    }

    func loadAll() -> [SavedPin] {
        guard let data = try? Data(contentsOf: storeURL),
              let pins = try? JSONDecoder().decode([SavedPin].self, from: data)
        else { return [] }
        return pins
    }

    func save(_ pins: [SavedPin]) {
        guard let data = try? JSONEncoder().encode(pins) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
