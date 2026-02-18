import Foundation

struct SavedPin: Codable, Identifiable {
    let id: UUID
    var name: String
    let latitude: Double
    let longitude: Double
    let createdAt: Date

    init(name: String, latitude: Double, longitude: Double) {
        self.id = UUID()
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = Date()
    }
}
