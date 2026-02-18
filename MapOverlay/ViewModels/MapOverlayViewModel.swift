import SwiftUI
import GoogleMaps

@MainActor
final class MapOverlayViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var opacity: Double = 0.5
    @Published var isLocked = false
    @Published var savedOverlays: [SavedOverlay] = []
    @Published var showingImagePicker = false
    @Published var showingSavedOverlays = false
    @Published var showingSaveDialog = false

    // The geographic bounds captured when the overlay is locked
    var lockedNorthEast: CLLocationCoordinate2D?
    var lockedSouthWest: CLLocationCoordinate2D?

    private let store = OverlayStore()

    init() {
        savedOverlays = store.loadAll()
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
            opacity: opacity
        )

        if saved != nil {
            savedOverlays = store.loadAll()
        }
    }

    func loadOverlay(_ overlay: SavedOverlay) {
        guard let image = store.loadImage(for: overlay) else { return }
        selectedImage = image
        opacity = overlay.opacity
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
}
