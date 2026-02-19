# MapOverlay App Design

## Overview

iOS app (SwiftUI + Google Maps SDK) that lets users import any photo from their
library, overlay it semi-transparently on Google Maps, adjust transparency and
rotation, align the map to match the overlay, lock it as a geo-anchored layer,
and then use the map normally. Saved overlays (including rotation) and map pins
persist locally for reuse.

## Approach

**Ground Overlay API (GMSGroundOverlay)** — the overlay image is pinned to
geographic coordinates. During alignment, a floating UIView sits on top of the
map; after locking, it converts to a native `GMSGroundOverlay` that
pans/zooms with the map. Rotation is applied via `GMSGroundOverlay.bearing`.

## Architecture

### Two Modes

- **Alignment Mode**: Floating semi-transparent, rotatable image over the map.
  User adjusts opacity and rotation via sliders in a collapsible panel, and
  pans/zooms the map underneath to align. The panel can be hidden with a toggle
  button for a full-screen view.
- **Locked Mode**: `GMSGroundOverlay` replaces the floating view. Map works
  normally with the layer baked in. Opacity and rotation remain adjustable in
  real time. Controls expand from a single left-aligned floating button.

### Components

| Component | Responsibility |
|---|---|
| `MapOverlayApp` | App entry, Google Maps API key config |
| `ContentView` | Main view: map + control panel + top bar (search, pins, settings, sign-in) |
| `GoogleMapView` | `UIViewRepresentable` wrapping `GMSMapView`; renders ground overlays and pin markers |
| `OverlayImageView` | Floating semi-transparent rotatable image during alignment |
| `ControlPanelView` | Icons-only, left-aligned, collapsible; opacity/rotation sliders, lock/unlock/remove/save |
| `ImagePicker` | `PHPickerViewController` wrapper |
| `PlaceSearchView` | CLGeocoder-based place/address search sheet; returns coordinate + name |
| `SavedOverlaysView` | List of saved overlays to load |
| `SavedPinsView` | List of saved pins with navigate-to and delete |
| `SettingsView` | API key config, Google Sign-In |
| `SignInView` | Google Sign-In icon button with signed-in menu |
| `MapOverlayViewModel` | Central state: image, opacity, rotation, lock state, bounds, pins |
| `GoogleAuthService` | Google Sign-In handling |
| `OverlayStore` | Persistence: save/load overlays (image + bounds + opacity + rotation) |
| `PinStore` | Persistence: save/load pins (saved_pins.json) |
| `SavedOverlay` | Model: id, name, imagePath, NE/SW coordinates, opacity, rotation, createdAt |
| `SavedPin` | Model: id, name, latitude, longitude, createdAt |

### Data Flow

```
User picks image -> ViewModel.selectedImage
  -> OverlayImageView renders over map (with rotation via .rotationEffect)
  -> Opacity slider adjusts ViewModel.opacity -> view updates
  -> Rotation slider adjusts ViewModel.rotation -> view updates
  -> User pans/zooms MAP to align
  -> Lock:
      1. Read map visibleRegion (4 corners)
      2. Create GMSGroundOverlay with image + bounds + bearing (rotation)
      3. Add to GMSMapView, hide floating view
      4. isLocked = true
  -> Unlock: reverse of lock
  -> Save: OverlayStore persists image + bounds + opacity + rotation
  -> Load: OverlayStore restores overlay (including rotation), creates GMSGroundOverlay

User taps search icon -> PlaceSearchView sheet
  -> User types query -> CLGeocoder.geocodeAddressString
  -> User selects result -> ViewModel.addPin(name, coordinate)
  -> GMSMarker added to GoogleMapView, map animates to pin
  -> PinStore.save(pins) persists to saved_pins.json

User taps pins icon -> SavedPinsView sheet
  -> Tap pin -> map animates to pin location
  -> Swipe to delete or Clear All -> PinStore updated
```

### Persistence

#### OverlayStore
- Images saved to app's Documents/overlays/ directory as PNG
- Metadata (bounds, opacity, rotation, name, timestamp) saved as JSON (metadata.json)
- Model: `SavedOverlay` with Codable conformance

#### PinStore
- Pins saved to app's Documents/saved_pins.json
- Model: `SavedPin` with Codable conformance
- Pins rendered as `GMSMarker` instances on the map

### Tech Stack

- SwiftUI with UIViewRepresentable for Google Maps
- Google Maps SDK via Swift Package Manager
- PHPickerViewController for photo selection
- CLGeocoder for place/address search
- CoreLocation for My Location
- FileManager + JSONEncoder for persistence

### UI Layout

```
+-------------------------------------+
|  [Search] [Pins] [Settings] [User]  |  <- top-left icons
|                                      |
|         Google Map                   |
|   +-------------------------+       |
|   | Overlay Image           |       |
|   | (semi-transparent,      |       |
|   |  rotated)               |       |
|   +-------------------------+       |
|              [Pin markers]          |
|                                      |
+-------------------------------------+

Alignment panel (bottom, collapsible):
  [opacity slider]
  [rotation slider]
  [Lock] [Remove]
  [toggle chevron]

Locked mode (bottom-left):
  [ellipsis] -> expands to:
    [opacity slider] [rotation slider]
    [Unlock] [Save] [Remove]

Idle mode (bottom-left):
  [Import] [Saved]
```

### Error Handling

- No image -> Lock/Save disabled
- Picker cancelled -> no-op
- Invalid image -> alert
- No API key -> setup instructions at launch
- No saved overlays -> empty state with prompt
- No saved pins -> empty state with prompt
- Geocoder returns no results -> "No results found" message
