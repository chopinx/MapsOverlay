import SwiftUI
import GoogleMaps

@MainActor
final class MapOverlayViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var opacity: Double = 0.5
    @Published var rotation: Double = 0
    @Published var isLocked = false
    @Published var savedOverlays: [SavedOverlay] = []
    @Published var showingImagePicker = false
    @Published var showingSavedOverlays = false
    @Published var showingSaveDialog = false
    @Published var savedPins: [SavedPin] = []
    @Published var currentBoundary: PlaceBoundary?
    @Published var isTransformMode = false
    @Published var transformCorners: FreeTransformCorners = .identity
    @Published var errorMessage: String?
    @Published var currentVisibleRegion: GMSVisibleRegion?
    @Published var animateTarget: CLLocationCoordinate2D?
    @Published var lockedNorthEast: CLLocationCoordinate2D?
    @Published var lockedSouthWest: CLLocationCoordinate2D?
    @Published var searchResults: [SearchResult] = []

    private let store: OverlayStore
    private let pinStore: PinStore
    private let boundaryService: BoundaryService
    private let transformService: FreeTransformService
    private let geocodingService: GeocodingService
    private var originalImage: UIImage?

    init(
        store: OverlayStore = .init(),
        pinStore: PinStore = .init(),
        boundaryService: BoundaryService = .init(),
        transformService: FreeTransformService = .init(),
        geocodingService: GeocodingService = .init()
    ) {
        self.store = store
        self.pinStore = pinStore
        self.boundaryService = boundaryService
        self.transformService = transformService
        self.geocodingService = geocodingService
        savedOverlays = store.loadAll()
        savedPins = pinStore.loadAll()
    }

    func lockOverlay() {
        guard selectedImage != nil,
              let visibleRegion = currentVisibleRegion else { return }

        bakeTransformIfNeeded()

        let bounds = GMSCoordinateBounds(region: visibleRegion)
        lockedNorthEast = bounds.northEast
        lockedSouthWest = bounds.southWest
        isTransformMode = false
        isLocked = true
    }

    private func bakeTransformIfNeeded() {
        guard !transformCorners.isIdentity,
              let image = selectedImage else { return }

        originalImage = image
        if let bakedImage = transformService.bakeTransform(image: image, corners: transformCorners) {
            selectedImage = bakedImage
        }
    }

    func unlockOverlay() {
        if let original = originalImage {
            selectedImage = original
            originalImage = nil
        }
        isLocked = false
    }

    func removeOverlay() {
        selectedImage = nil
        isLocked = false
        isTransformMode = false
        transformCorners = .identity
        originalImage = nil
        opacity = 0.5
        rotation = 0
        lockedNorthEast = nil
        lockedSouthWest = nil
    }

    func toggleTransformMode() {
        isTransformMode.toggle()
    }

    func resetTransform() {
        transformCorners = .identity
    }

    func saveOverlay(name: String) {
        guard let image = selectedImage,
              let ne = lockedNorthEast,
              let sw = lockedSouthWest
        else { return }

        do {
            _ = try store.saveOverlay(
                image: image,
                name: name,
                northEastLatitude: ne.latitude,
                northEastLongitude: ne.longitude,
                southWestLatitude: sw.latitude,
                southWestLongitude: sw.longitude,
                opacity: opacity,
                rotation: rotation
            )
            savedOverlays = store.loadAll()
        } catch {
            errorMessage = "Failed to save overlay: \(error.localizedDescription)"
        }
    }

    func loadOverlay(_ overlay: SavedOverlay) {
        guard let image = store.loadImage(for: overlay) else { return }
        transformCorners = .identity
        isTransformMode = false
        originalImage = nil
        selectedImage = image
        opacity = overlay.opacity
        rotation = overlay.rotation
        lockedNorthEast = CLLocationCoordinate2D(
            latitude: overlay.northEastLatitude,
            longitude: overlay.northEastLongitude
        )
        lockedSouthWest = CLLocationCoordinate2D(
            latitude: overlay.southWestLatitude,
            longitude: overlay.southWestLongitude
        )
        isLocked = true
    }

    func deleteOverlay(_ overlay: SavedOverlay) {
        do {
            try store.delete(overlay)
            savedOverlays = store.loadAll()
        } catch {
            errorMessage = "Failed to delete overlay: \(error.localizedDescription)"
        }
    }

    // MARK: - Boundary

    private var boundaryTask: Task<Void, Never>?

    func fetchBoundary(for query: String) {
        boundaryTask?.cancel()
        currentBoundary = nil
        boundaryTask = Task {
            let result = await boundaryService.fetchBoundary(query: query)
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let boundary):
                currentBoundary = boundary
            case .failure(let error):
                errorMessage = "Boundary fetch failed: \(error)"
            }
        }
    }

    // MARK: - Place search

    func searchPlaces(query: String) async {
        do {
            searchResults = try await geocodingService.search(query: query)
        } catch {
            searchResults = []
            errorMessage = "Search failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Pin management

    func addPin(name: String, coordinate: CLLocationCoordinate2D) {
        let pin = SavedPin(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude)
        savedPins.append(pin)
        do {
            try pinStore.save(savedPins)
        } catch {
            errorMessage = "Failed to save pins: \(error.localizedDescription)"
        }
    }

    func deletePin(_ pin: SavedPin) {
        savedPins.removeAll { $0.id == pin.id }
        do {
            try pinStore.save(savedPins)
        } catch {
            errorMessage = "Failed to save pins: \(error.localizedDescription)"
        }
    }

    func clearAllPins() {
        savedPins.removeAll()
        do {
            try pinStore.save(savedPins)
        } catch {
            errorMessage = "Failed to save pins: \(error.localizedDescription)"
        }
    }
}
