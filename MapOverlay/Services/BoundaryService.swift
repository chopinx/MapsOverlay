import CoreLocation
import Foundation

struct BoundaryPolygon: Equatable {
    let outer: [CLLocationCoordinate2D]
    let holes: [[CLLocationCoordinate2D]]

    static func == (lhs: BoundaryPolygon, rhs: BoundaryPolygon) -> Bool {
        guard lhs.outer.count == rhs.outer.count, lhs.holes.count == rhs.holes.count else { return false }
        for (a, b) in zip(lhs.outer, rhs.outer) where a.latitude != b.latitude || a.longitude != b.longitude { return false }
        for (holeA, holeB) in zip(lhs.holes, rhs.holes) {
            guard holeA.count == holeB.count else { return false }
            for (a, b) in zip(holeA, holeB) where a.latitude != b.latitude || a.longitude != b.longitude { return false }
        }
        return true
    }
}

struct PlaceBoundary: Equatable {
    let id = UUID()
    let polygons: [BoundaryPolygon]

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
        request.setValue(Config.nominatimUserAgent, forHTTPHeaderField: "User-Agent")

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

        let polygons: [BoundaryPolygon]
        switch type {
        case "Polygon":
            guard let rings = coordinates as? [[[Double]]],
                  let polygon = parsePolygon(rings)
            else { return nil }
            polygons = [polygon]
        case "MultiPolygon":
            guard let multi = coordinates as? [[[[Double]]]] else { return nil }
            polygons = multi.compactMap { parsePolygon($0) }
        default:
            return nil
        }

        guard !polygons.isEmpty else { return nil }
        return PlaceBoundary(polygons: polygons)
    }

    private func parsePolygon(_ rings: [[[Double]]]) -> BoundaryPolygon? {
        guard let firstRing = rings.first,
              let outer = parseRing(firstRing)
        else { return nil }

        let holes = rings.dropFirst().compactMap { parseRing($0) }
        return BoundaryPolygon(outer: outer, holes: holes)
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
