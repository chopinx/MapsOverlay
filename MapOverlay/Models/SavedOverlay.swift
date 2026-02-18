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
    let createdAt: Date

    init(
        name: String,
        imagePath: String,
        northEastLatitude: Double,
        northEastLongitude: Double,
        southWestLatitude: Double,
        southWestLongitude: Double,
        opacity: Double
    ) {
        self.id = UUID()
        self.name = name
        self.imagePath = imagePath
        self.northEastLatitude = northEastLatitude
        self.northEastLongitude = northEastLongitude
        self.southWestLatitude = southWestLatitude
        self.southWestLongitude = southWestLongitude
        self.opacity = opacity
        self.createdAt = Date()
    }
}
