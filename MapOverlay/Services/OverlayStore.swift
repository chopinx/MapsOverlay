import UIKit

final class OverlayStore {
    private let fileManager = FileManager.default

    private var overlaysDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("overlays", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

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
    ) -> SavedOverlay? {
        let fileName = UUID().uuidString + ".png"
        let imageURL = overlaysDirectory.appendingPathComponent(fileName)

        guard let data = image.pngData() else { return nil }
        do {
            try data.write(to: imageURL)
        } catch {
            return nil
        }

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
        saveMetadata(all)
        return overlay
    }

    func loadAll() -> [SavedOverlay] {
        guard let data = try? Data(contentsOf: metadataURL),
              let overlays = try? JSONDecoder().decode([SavedOverlay].self, from: data)
        else { return [] }
        return overlays
    }

    func loadImage(for overlay: SavedOverlay) -> UIImage? {
        let url = overlaysDirectory.appendingPathComponent(overlay.imagePath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func delete(_ overlay: SavedOverlay) {
        let imageURL = overlaysDirectory.appendingPathComponent(overlay.imagePath)
        try? fileManager.removeItem(at: imageURL)

        var all = loadAll()
        all.removeAll { $0.id == overlay.id }
        saveMetadata(all)
    }

    private func saveMetadata(_ overlays: [SavedOverlay]) {
        guard let data = try? JSONEncoder().encode(overlays) else { return }
        try? data.write(to: metadataURL)
    }
}
