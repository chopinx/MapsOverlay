import SwiftUI
import CoreLocation

struct PlaceSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    @State private var geocoder = CLGeocoder()
    var onPlaceSelected: (CLLocationCoordinate2D, String, String) -> Void

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if results.isEmpty && !query.isEmpty {
                    Text("No results found")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(results) { result in
                        Button {
                            onPlaceSelected(result.coordinate, result.name, query)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                if let detail = result.detail {
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search places")
            .onSubmit(of: .search) { search() }
            .onChange(of: query) { _, newValue in
                if newValue.isEmpty { results = [] }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func search() {
        guard !query.isEmpty else { return }
        isSearching = true
        geocoder.cancelGeocode()
        geocoder.geocodeAddressString(query) { placemarks, _ in
            DispatchQueue.main.async {
                isSearching = false
                results = (placemarks ?? []).compactMap { placemark in
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
    }
}

private struct SearchResult: Identifiable {
    let id = UUID()
    let name: String
    let detail: String?
    let coordinate: CLLocationCoordinate2D
}
