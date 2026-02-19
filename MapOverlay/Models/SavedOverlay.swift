import Foundation

struct SavedOverlay: Codable, Identifiable {
    let id: UUID
    var name: String
    let imagePath: String
    let northEastLatitude: Double
    let northEastLongitude: Double
    let southWestLatitude: Double
    let southWestLongitude: Double
    var opacity: Double
    var rotation: Double
    let createdAt: Date

    init(
        name: String,
        imagePath: String,
        northEastLatitude: Double,
        northEastLongitude: Double,
        southWestLatitude: Double,
        southWestLongitude: Double,
        opacity: Double,
        rotation: Double = 0
    ) {
        self.id = UUID()
        self.name = name
        self.imagePath = imagePath
        self.northEastLatitude = northEastLatitude
        self.northEastLongitude = northEastLongitude
        self.southWestLatitude = southWestLatitude
        self.southWestLongitude = southWestLongitude
        self.opacity = opacity
        self.rotation = rotation
        self.createdAt = Date()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        imagePath = try container.decode(String.self, forKey: .imagePath)
        northEastLatitude = try container.decode(Double.self, forKey: .northEastLatitude)
        northEastLongitude = try container.decode(Double.self, forKey: .northEastLongitude)
        southWestLatitude = try container.decode(Double.self, forKey: .southWestLatitude)
        southWestLongitude = try container.decode(Double.self, forKey: .southWestLongitude)
        opacity = try container.decode(Double.self, forKey: .opacity)
        rotation = try container.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
