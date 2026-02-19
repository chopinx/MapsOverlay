import CoreLocation
import Foundation

final class BoundaryService: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchBoundary(query: String) async -> Result<PlaceBoundary?, BoundaryError> {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://nominatim.openstreetmap.org/search?q=\(encoded)&format=json&polygon_geojson=1&limit=1")
        else { return .failure(.parseError) }

        var request = URLRequest(url: url)
        request.setValue(Config.nominatimUserAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            return .failure(.networkError(underlying: error))
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else { return .failure(.networkError(underlying: URLError(.badServerResponse))) }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = json.first
        else { return .success(nil) }

        guard let geojson = first["geojson"] as? [String: Any],
              let type = geojson["type"] as? String,
              let coordinates = geojson["coordinates"]
        else { return .failure(.parseError) }

        let polygons: [BoundaryPolygon]
        switch type {
        case "Polygon":
            guard let rings = coordinates as? [[[Double]]],
                  let polygon = parsePolygon(rings)
            else { return .failure(.parseError) }
            polygons = [polygon]
        case "MultiPolygon":
            guard let multi = coordinates as? [[[[Double]]]] else { return .failure(.parseError) }
            polygons = multi.compactMap { parsePolygon($0) }
        default:
            return .failure(.parseError)
        }

        guard !polygons.isEmpty else { return .failure(.noResults) }
        return .success(PlaceBoundary(polygons: polygons))
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
