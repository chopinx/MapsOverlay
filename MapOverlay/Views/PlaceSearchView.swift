import SwiftUI
import CoreLocation

struct PlaceSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    private let geocodingService = GeocodingService()
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
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
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
                if newValue.isEmpty {
                    results = []
                    errorMessage = nil
                }
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
        errorMessage = nil
        Task {
            do {
                results = try await geocodingService.search(query: query)
                isSearching = false
            } catch let error as CLError where error.code == .network {
                errorMessage = "Network error. Check your connection and try again."
                isSearching = false
            } catch {
                errorMessage = "Search failed: \(error.localizedDescription)"
                isSearching = false
            }
        }
    }
}
