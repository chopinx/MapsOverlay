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

    // The geographic bounds captured when the overlay is locked
    var lockedNorthEast: CLLocationCoordinate2D?
    var lockedSouthWest: CLLocationCoordinate2D?

    private let store = OverlayStore()
    private let pinStore = PinStore()
    private let boundaryService = BoundaryService()
    private let transformService = FreeTransformService()
    private var originalImage: UIImage?

    init() {
        savedOverlays = store.loadAll()
        savedPins = pinStore.loadAll()
    }

    func lockOverlay(visibleRegion: GMSVisibleRegion) {
        guard selectedImage != nil else { return }

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

        let saved = store.saveOverlay(
            image: image,
            name: name,
            northEastLatitude: ne.latitude,
            northEastLongitude: ne.longitude,
            southWestLatitude: sw.latitude,
            southWestLongitude: sw.longitude,
            opacity: opacity,
            rotation: rotation
        )

        if saved != nil {
            savedOverlays = store.loadAll()
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
        store.delete(overlay)
        savedOverlays = store.loadAll()
    }

    // MARK: - Boundary

    private var boundaryTask: Task<Void, Never>?

    func fetchBoundary(for query: String) {
        boundaryTask?.cancel()
        currentBoundary = nil
        boundaryTask = Task {
            let result = await boundaryService.fetchBoundary(query: query)
            guard !Task.isCancelled else { return }
            currentBoundary = result
        }
    }

    // MARK: - Pin management

    func addPin(name: String, coordinate: CLLocationCoordinate2D) {
        let pin = SavedPin(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude)
        savedPins.append(pin)
        pinStore.save(savedPins)
    }

    func deletePin(_ pin: SavedPin) {
        savedPins.removeAll { $0.id == pin.id }
        pinStore.save(savedPins)
    }

    func clearAllPins() {
        savedPins.removeAll()
        pinStore.save(savedPins)
    }
}
