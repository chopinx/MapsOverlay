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
    @Published var showingSavedPins = false

    // The geographic bounds captured when the overlay is locked
    var lockedNorthEast: CLLocationCoordinate2D?
    var lockedSouthWest: CLLocationCoordinate2D?

    private let store = OverlayStore()
    private let pinStore = PinStore()

    init() {
        savedOverlays = store.loadAll()
        savedPins = pinStore.loadAll()
    }

    func lockOverlay(visibleRegion: GMSVisibleRegion) {
        guard selectedImage != nil else { return }

        let bounds = GMSCoordinateBounds(region: visibleRegion)
        lockedNorthEast = bounds.northEast
        lockedSouthWest = bounds.southWest
        isLocked = true
    }

    func unlockOverlay() {
        isLocked = false
    }

    func removeOverlay() {
        selectedImage = nil
        isLocked = false
        rotation = 0
        lockedNorthEast = nil
        lockedSouthWest = nil
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
