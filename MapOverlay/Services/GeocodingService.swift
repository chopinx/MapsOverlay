import CoreLocation
import Foundation

struct SearchResult: Identifiable {
    let id = UUID()
    let name: String
    let detail: String?
    let coordinate: CLLocationCoordinate2D
}

final class GeocodingService {
    private let geocoder = CLGeocoder()

    func search(query: String) async throws -> [SearchResult] {
        geocoder.cancelGeocode()
        let placemarks = try await geocoder.geocodeAddressString(query)
        return placemarks.compactMap { placemark in
            guard let location = placemark.location else { return nil }

            let name = [placemark.name, placemark.locality]
                .compactMap { $0 }
                .joined(separator: ", ")

            let detail = [placemark.administrativeArea, placemark.country]
                .compactMap { $0 }
                .joined(separator: ", ")

            return SearchResult(
                name: name.isEmpty ? "Unknown" : name,
                detail: detail.isEmpty ? nil : detail,
                coordinate: location.coordinate
            )
        }
    }
}
