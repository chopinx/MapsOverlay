import UIKit

final class OverlayStore {
    private let fileManager = FileManager.default
    private let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.directory = docs.appendingPathComponent("overlays", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    private var overlaysDirectory: URL { directory }

    private var metadataURL: URL {
        overlaysDirectory.appendingPathComponent("metadata.json")
    }

    func saveOverlay(
        image: UIImage,
        name: String,
        northEastLatitude: Double,
        northEastLongitude: Double,
        southWestLatitude: Double,
        southWestLongitude: Double,
        opacity: Double,
        rotation: Double = 0
    ) throws -> SavedOverlay {
        let fileName = UUID().uuidString + ".png"
        let imageURL = overlaysDirectory.appendingPathComponent(fileName)

        guard let data = image.pngData() else {
            throw OverlayStoreError.imageConversionFailed
        }
        try data.write(to: imageURL, options: .atomic)

        let overlay = SavedOverlay(
            name: name,
            imagePath: fileName,
            northEastLatitude: northEastLatitude,
            northEastLongitude: northEastLongitude,
            southWestLatitude: southWestLatitude,
            southWestLongitude: southWestLongitude,
            opacity: opacity,
            rotation: rotation
        )

        var all = loadAll()
        all.append(overlay)
        try saveMetadata(all)
        return overlay
    }

    func loadAll() -> [SavedOverlay] {
        guard let data = try? Data(contentsOf: metadataURL) else { return [] }
        // Error-tolerant decoding: skip corrupt entries instead of returning empty array
        if let overlays = try? JSONDecoder().decode([SavedOverlay].self, from: data) {
            return overlays
        }
        // Fall back to decoding entry-by-entry, skipping corrupt ones
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return jsonArray.compactMap { dict in
            guard let entryData = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
            return try? JSONDecoder().decode(SavedOverlay.self, from: entryData)
        }
    }

    func loadImage(for overlay: SavedOverlay) -> UIImage? {
        let url = overlaysDirectory.appendingPathComponent(overlay.imagePath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func delete(_ overlay: SavedOverlay) throws {
        let imageURL = overlaysDirectory.appendingPathComponent(overlay.imagePath)
        try fileManager.removeItem(at: imageURL)

        var all = loadAll()
        all.removeAll { $0.id == overlay.id }
        try saveMetadata(all)
    }

    private func saveMetadata(_ overlays: [SavedOverlay]) throws {
        let data = try JSONEncoder().encode(overlays)
        // Backup existing metadata before overwriting
        if fileManager.fileExists(atPath: metadataURL.path) {
            let backupURL = metadataURL.deletingLastPathComponent()
                .appendingPathComponent("metadata.backup.json")
            try? fileManager.removeItem(at: backupURL)
            try? fileManager.copyItem(at: metadataURL, to: backupURL)
        }
        try data.write(to: metadataURL, options: .atomic)
    }
}

enum OverlayStoreError: Error {
    case imageConversionFailed
}
