import CoreLocation

struct BoundaryPolygon: Equatable {
    let outer: [CLLocationCoordinate2D]
    let holes: [[CLLocationCoordinate2D]]

    static func == (lhs: BoundaryPolygon, rhs: BoundaryPolygon) -> Bool {
        guard lhs.outer.count == rhs.outer.count, lhs.holes.count == rhs.holes.count else { return false }
        for (a, b) in zip(lhs.outer, rhs.outer) where a.latitude != b.latitude || a.longitude != b.longitude { return false }
        for (holeA, holeB) in zip(lhs.holes, rhs.holes) {
            guard holeA.count == holeB.count else { return false }
            for (a, b) in zip(holeA, holeB) where a.latitude != b.latitude || a.longitude != b.longitude { return false }
        }
        return true
    }
}

struct PlaceBoundary: Equatable {
    let id = UUID()
    let polygons: [BoundaryPolygon]

    static func == (lhs: PlaceBoundary, rhs: PlaceBoundary) -> Bool {
        lhs.polygons == rhs.polygons
    }
}
