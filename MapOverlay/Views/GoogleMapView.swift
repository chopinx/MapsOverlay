import SwiftUI
import GoogleMaps

struct GoogleMapView: UIViewRepresentable {
    @ObservedObject var viewModel: MapOverlayViewModel
    var onVisibleRegionChanged: ((GMSVisibleRegion) -> Void)?
    var animateToCoordinate: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(
            withLatitude: 37.7749,
            longitude: -122.4194,
            zoom: 12.0
        )
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.delegate = context.coordinator
        mapView.settings.myLocationButton = true
        mapView.isMyLocationEnabled = true
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.clear()

        // Ground overlay when locked
        if viewModel.isLocked,
           let image = viewModel.selectedImage,
           let ne = viewModel.lockedNorthEast,
           let sw = viewModel.lockedSouthWest {
            let bounds = GMSCoordinateBounds(
                coordinate: sw,
                coordinate: ne
            )
            let groundOverlay = GMSGroundOverlay(bounds: bounds, icon: image)
            groundOverlay.opacity = Float(viewModel.opacity)
            groundOverlay.map = mapView
        }

        // Saved pin markers
        for pin in viewModel.savedPins {
            let marker = GMSMarker(position: CLLocationCoordinate2D(
                latitude: pin.latitude,
                longitude: pin.longitude
            ))
            marker.title = pin.name
            marker.map = mapView
        }

        // Animate to newly added pin
        if let target = animateToCoordinate,
           target.latitude != context.coordinator.lastTarget?.latitude ||
           target.longitude != context.coordinator.lastTarget?.longitude {
            context.coordinator.lastTarget = target
            let camera = GMSCameraPosition.camera(
                withLatitude: target.latitude,
                longitude: target.longitude,
                zoom: 15.0
            )
            mapView.animate(to: camera)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, GMSMapViewDelegate {
        let parent: GoogleMapView
        var lastTarget: CLLocationCoordinate2D?

        init(_ parent: GoogleMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            let region = mapView.projection.visibleRegion()
            parent.onVisibleRegionChanged?(region)
        }
    }
}
