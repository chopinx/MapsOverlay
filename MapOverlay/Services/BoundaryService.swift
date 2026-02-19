import CoreLocation
import Foundation

struct PlaceBoundary: Equatable {
    let id = UUID()
    let polygons: [[CLLocationCoordinate2D]]

    static func == (lhs: PlaceBoundary, rhs: PlaceBoundary) -> Bool {
        lhs.id == rhs.id
    }
}

final class BoundaryService: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchBoundary(query: String) async -> PlaceBoundary? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://nominatim.openstreetmap.org/search?q=\(encoded)&format=json&polygon_geojson=1&limit=1")
        else { return nil }

        var request = URLRequest(url: url)
        request.setValue("MapOverlay/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await session.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = json.first,
              let geojson = first["geojson"] as? [String: Any],
              let type = geojson["type"] as? String,
              let coordinates = geojson["coordinates"]
        else { return nil }

        let polygons: [[CLLocationCoordinate2D]]
        switch type {
        case "Polygon":
            guard let rings = coordinates as? [[[Double]]] else { return nil }
            polygons = rings.compactMap { parseRing($0) }
        case "MultiPolygon":
            guard let multi = coordinates as? [[[[Double]]]] else { return nil }
            polygons = multi.flatMap { polygon in
                polygon.compactMap { parseRing($0) }
            }
        default:
            return nil
        }

        guard !polygons.isEmpty else { return nil }
        return PlaceBoundary(polygons: polygons)
    }

    private func parseRing(_ ring: [[Double]]) -> [CLLocationCoordinate2D]? {
        let coords = ring.compactMap { point -> CLLocationCoordinate2D? in
            guard point.count >= 2 else { return nil }
            // GeoJSON uses [longitude, latitude] order
            return CLLocationCoordinate2D(latitude: point[1], longitude: point[0])
        }
        // GeoJSON requires at least 4 points (3 distinct + closing)
        return coords.count >= 4 ? coords : nil
    }
}
