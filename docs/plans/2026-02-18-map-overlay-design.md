# MapOverlay App Design

## Overview

iOS app (SwiftUI + Google Maps SDK) that lets users import any photo from their
library, overlay it semi-transparently on Google Maps, adjust transparency,
align the map to match the overlay, lock it as a geo-anchored layer, and then
use the map normally. Saved overlays persist locally for reuse.

## Approach

**Ground Overlay API (GMSGroundOverlay)** — the overlay image is pinned to
geographic coordinates. During alignment, a floating UIView sits on top of the
map; after locking, it converts to a native `GMSGroundOverlay` that
pans/zooms with the map.

## Architecture

### Two Modes

- **Alignment Mode**: Floating semi-transparent image over the map. User
  adjusts opacity and pans/zooms the map underneath to align.
- **Locked Mode**: `GMSGroundOverlay` replaces the floating view. Map works
  normally with the layer baked in.

### Components

| Component | Responsibility |
|---|---|
| `MapOverlayApp` | App entry, Google Maps API key config |
| `ContentView` | Main view: map + control panel |
| `GoogleMapView` | `UIViewRepresentable` wrapping `GMSMapView` |
| `OverlayImageView` | Floating semi-transparent image during alignment |
| `ControlPanelView` | Slider, import/lock/unlock/remove/save/load buttons |
| `ImagePicker` | `PHPickerViewController` wrapper |
| `SavedOverlaysView` | List of saved overlays to load |
| `MapOverlayViewModel` | Central state: image, opacity, lock state, bounds |
| `OverlayStore` | Persistence: save/load overlays (image + bounds + opacity) |
| `SavedOverlay` | Model: image path, NE/SW coordinates, opacity, name, date |

### Data Flow

```
User picks image -> ViewModel.selectedImage
  -> OverlayImageView renders over map
  -> Slider adjusts ViewModel.opacity -> view updates
  -> User pans/zooms MAP to align
  -> Lock:
      1. Read map visibleRegion (4 corners)
      2. Create GMSGroundOverlay with image + bounds
      3. Add to GMSMapView, hide floating view
      4. isLocked = true
  -> Unlock: reverse of lock
  -> Save: OverlayStore persists image + bounds + opacity
  -> Load: OverlayStore restores overlay, creates GMSGroundOverlay
```

### Persistence (OverlayStore)

- Images saved to app's Documents directory
- Metadata (bounds, opacity, name, timestamp) saved as JSON
- Model: `SavedOverlay` with Codable conformance
- List view to browse/load/delete saved overlays

### Tech Stack

- SwiftUI with UIViewRepresentable for Google Maps
- Google Maps SDK via Swift Package Manager
- PHPickerViewController for photo selection
- FileManager + JSONEncoder for persistence

### UI Layout

```
+-----------------------------+
|         Google Map           |
|   +-------------------+     |
|   | Overlay Image     |     |
|   | (semi-transparent)|     |
|   +-------------------+     |
|                             |
+-----------------------------+
| [Import] [Saved]   Opacity |
|              ===*=======    |
| [Lock/Unlock]    [Remove]   |
+-----------------------------+
```

### Error Handling

- No image -> Lock/Save disabled
- Picker cancelled -> no-op
- Invalid image -> alert
- No API key -> setup instructions at launch
- No saved overlays -> empty state with prompt
