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
        coordinator.updateGroundOverlay(on: mapView, viewModel: viewModel)
        coordinator.updateMarkers(on: mapView, viewModel: viewModel)
        let boundaryChanged = coordinator.updateBoundary(on: mapView, viewModel: viewModel)
        coordinator.animateCamera(on: mapView, viewModel: viewModel, animateToCoordinate: animateToCoordinate, boundaryChanged: boundaryChanged)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor class Coordinator: NSObject, GMSMapViewDelegate {
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
            parent.viewModel.mapProjection = mapView.projection
            parent.viewModel.mapViewSize = mapView.bounds.size
            parent.onVisibleRegionChanged?(region)
        }

        // MARK: - Update helpers

        func updateGroundOverlay(on mapView: GMSMapView, viewModel: MapOverlayViewModel) {
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

                if let existing = groundOverlay {
                    existing.opacity = Float(viewModel.opacity)
                    existing.bearing = viewModel.rotation

                    let boundsChanged = existing.bounds?.northEast.latitude != ne.latitude
                        || existing.bounds?.northEast.longitude != ne.longitude
                        || existing.bounds?.southWest.latitude != sw.latitude
                        || existing.bounds?.southWest.longitude != sw.longitude
                    let imageChanged = existing.icon !== image

                    if boundsChanged || imageChanged {
                        existing.map = nil
                        groundOverlay = createOverlay()
                    }
                } else {
                    groundOverlay = createOverlay()
                }
            } else {
                groundOverlay?.map = nil
                groundOverlay = nil
            }
        }

        func updateMarkers(on mapView: GMSMapView, viewModel: MapOverlayViewModel) {
            let currentPinIDs = Set(viewModel.savedPins.map { $0.id })
            let existingPinIDs = Set(markers.keys)

            for id in existingPinIDs.subtracting(currentPinIDs) {
                markers[id]?.map = nil
                markers.removeValue(forKey: id)
            }

            for pin in viewModel.savedPins where !existingPinIDs.contains(pin.id) {
                let marker = GMSMarker(position: CLLocationCoordinate2D(
                    latitude: pin.latitude,
                    longitude: pin.longitude
                ))
                marker.title = pin.name
                marker.map = mapView
                markers[pin.id] = marker
            }
        }

        @discardableResult
        func updateBoundary(on mapView: GMSMapView, viewModel: MapOverlayViewModel) -> Bool {
            let boundaryChanged = lastBoundary != viewModel.currentBoundary
            guard boundaryChanged else { return false }

            for polygon in boundaryPolygons {
                polygon.map = nil
            }
            boundaryPolygons.removeAll()
            lastBoundary = viewModel.currentBoundary

            if let boundary = viewModel.currentBoundary {
                for polygonData in boundary.polygons {
                    guard !polygonData.outer.isEmpty else { continue }

                    let path = GMSMutablePath()
                    for coord in polygonData.outer {
                        path.add(coord)
                    }

                    let polygon = GMSPolygon(path: path)
                    polygon.holes = polygonData.holes.map { hole in
                        let holePath = GMSMutablePath()
                        for coord in hole {
                            holePath.add(coord)
                        }
                        return holePath
                    }
                    polygon.fillColor = UIColor.systemBlue.withAlphaComponent(0.15)
                    polygon.strokeColor = UIColor.systemBlue.withAlphaComponent(0.45)
                    polygon.strokeWidth = 2
                    polygon.zIndex = 1
                    polygon.map = mapView
                    boundaryPolygons.append(polygon)
                }
            }

            return true
        }

        func animateCamera(on mapView: GMSMapView, viewModel: MapOverlayViewModel, animateToCoordinate: CLLocationCoordinate2D?, boundaryChanged: Bool) {
            if boundaryChanged, let boundary = viewModel.currentBoundary, !boundary.polygons.isEmpty {
                var bounds = GMSCoordinateBounds()
                for polygonData in boundary.polygons {
                    for coord in polygonData.outer {
                        bounds = bounds.includingCoordinate(coord)
                    }
                }
                let update = GMSCameraUpdate.fit(bounds, withPadding: 60)
                mapView.animate(with: update)
            }

            if let target = animateToCoordinate,
               (target.latitude != lastTarget?.latitude ||
                target.longitude != lastTarget?.longitude) {
                lastTarget = target

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
    }
}
