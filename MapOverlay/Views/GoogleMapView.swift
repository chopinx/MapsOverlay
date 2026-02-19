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
        let coordinator = context.coordinator

        // Ground overlay when locked
        if viewModel.isLocked,
           let image = viewModel.selectedImage,
           let ne = viewModel.lockedNorthEast,
           let sw = viewModel.lockedSouthWest {
            let bounds = GMSCoordinateBounds(coordinate: sw, coordinate: ne)

            func createOverlay() -> GMSGroundOverlay {
                let overlay = GMSGroundOverlay(bounds: bounds, icon: image)
                overlay.opacity = Float(viewModel.opacity)
                overlay.bearing = viewModel.rotation
                overlay.map = mapView
                return overlay
            }

            if let existing = coordinator.groundOverlay {
                // Update in-place to avoid flicker
                existing.opacity = Float(viewModel.opacity)
                existing.bearing = viewModel.rotation

                // If bounds or image changed, recreate
                let boundsChanged = existing.bounds?.northEast.latitude != ne.latitude
                    || existing.bounds?.northEast.longitude != ne.longitude
                    || existing.bounds?.southWest.latitude != sw.latitude
                    || existing.bounds?.southWest.longitude != sw.longitude
                let imageChanged = existing.icon !== image

                if boundsChanged || imageChanged {
                    existing.map = nil
                    coordinator.groundOverlay = createOverlay()
                }
            } else {
                coordinator.groundOverlay = createOverlay()
            }
        } else {
            // Not locked — remove existing overlay
            coordinator.groundOverlay?.map = nil
            coordinator.groundOverlay = nil
        }

        // Saved pin markers — only add/remove changed ones
        let currentPinIDs = Set(viewModel.savedPins.map { $0.id })
        let existingPinIDs = Set(coordinator.markers.keys)

        // Remove markers for pins that no longer exist
        for id in existingPinIDs.subtracting(currentPinIDs) {
            coordinator.markers[id]?.map = nil
            coordinator.markers.removeValue(forKey: id)
        }

        // Add markers for new pins
        for pin in viewModel.savedPins where !existingPinIDs.contains(pin.id) {
            let marker = GMSMarker(position: CLLocationCoordinate2D(
                latitude: pin.latitude,
                longitude: pin.longitude
            ))
            marker.title = pin.name
            marker.map = mapView
            coordinator.markers[pin.id] = marker
        }

        // Boundary polygons
        let boundaryChanged = coordinator.lastBoundary != viewModel.currentBoundary
        if boundaryChanged {
            for polygon in coordinator.boundaryPolygons {
                polygon.map = nil
            }
            coordinator.boundaryPolygons.removeAll()
            coordinator.lastBoundary = viewModel.currentBoundary

            if let boundary = viewModel.currentBoundary {
                for ring in boundary.polygons {
                    let path = GMSMutablePath()
                    for coord in ring {
                        path.add(coord)
                    }
                    let polygon = GMSPolygon(path: path)
                    polygon.fillColor = UIColor.systemBlue.withAlphaComponent(0.15)
                    polygon.strokeColor = UIColor.systemBlue.withAlphaComponent(0.45)
                    polygon.strokeWidth = 2
                    polygon.zIndex = 1
                    polygon.map = mapView
                    coordinator.boundaryPolygons.append(polygon)
                }
            }
        }

        // Fit camera to boundary when boundary arrives asynchronously
        if boundaryChanged, let boundary = viewModel.currentBoundary, !boundary.polygons.isEmpty {
            var bounds = GMSCoordinateBounds()
            for ring in boundary.polygons {
                for coord in ring {
                    bounds = bounds.includingCoordinate(coord)
                }
            }
            let update = GMSCameraUpdate.fit(bounds, withPadding: 60)
            mapView.animate(with: update)
        }

        // Animate camera to coordinate (for pin-only results without boundary)
        if let target = animateToCoordinate,
           (target.latitude != coordinator.lastTarget?.latitude ||
            target.longitude != coordinator.lastTarget?.longitude) {
            coordinator.lastTarget = target

            if viewModel.currentBoundary == nil {
                let camera = GMSCameraPosition.camera(
                    withLatitude: target.latitude,
                    longitude: target.longitude,
                    zoom: 15.0
                )
                mapView.animate(to: camera)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, GMSMapViewDelegate {
        let parent: GoogleMapView
        var lastTarget: CLLocationCoordinate2D?
        var groundOverlay: GMSGroundOverlay?
        var markers: [UUID: GMSMarker] = [:]
        var boundaryPolygons: [GMSPolygon] = []
        var lastBoundary: PlaceBoundary?

        init(_ parent: GoogleMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            let region = mapView.projection.visibleRegion()
            parent.onVisibleRegionChanged?(region)
        }
    }
}
