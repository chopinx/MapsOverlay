# MapsOverlay

iOS app that lets you overlay any image from your photo library onto Google Maps as a semi-transparent layer. Align the map to match your image, lock it as a geo-anchored overlay, and use Google Maps normally with the layer visible.

## Features

- Import any image from your iPhone photo library
- Adjustable transparency slider (5%-100%)
- Rotate overlay images (-180° to 180°); rotation persists with saved overlays
- Pan and zoom the map to align with your overlay image
- Lock the overlay as a geo-anchored ground layer (moves/scales/rotates with the map)
- Unlock to re-adjust alignment
- Save overlays locally for reuse (image + geographic bounds + opacity + rotation)
- Browse and load saved overlays
- Multi-pin support: search for places via CLGeocoder, pin them on the map, pins persist across app restarts
- Place search via Apple's CLGeocoder (address/place name lookup)
- Collapsible/hideable control panel in alignment mode
- Icons-only UI; left-aligned controls to avoid overlap with Google Maps built-in buttons
- My Location button (location when-in-use permission)
- Google Sign-In integration
- Settings view to configure Google Maps API key (persisted locally)

## Prerequisites

- Xcode 16.0+
- iOS 17.0+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Google Maps API key ([get one here](https://console.cloud.google.com/apis/credentials))
- Google OAuth client ID (for Sign-In)

## Setup

1. **Clone the repo**:
   ```bash
   git clone git@github.com:chopinx/MapsOverlay.git
   cd MapsOverlay
   ```

2. **Generate the Xcode project**:
   ```bash
   xcodegen generate
   ```

3. **Open and build**:
   ```bash
   open MapOverlay.xcodeproj
   ```
   Xcode will resolve SPM dependencies automatically on first open.

4. **Run** on a simulator or device. On first launch, the app will prompt you to enter your Google Maps API key in Settings.

## Architecture

MVVM pattern with SwiftUI:

```
MapOverlayApp (entry point, API key setup)
├── ContentView (main composition, top bar with icon buttons)
│   ├── GoogleMapView (UIViewRepresentable wrapping GMSMapView, renders ground overlays + pin markers)
│   ├── OverlayImageView (floating semi-transparent rotatable image during alignment)
│   ├── ControlPanelView (icons-only, left-aligned, collapsible; opacity/rotation sliders, lock/unlock/save/remove)
│   ├── PlaceSearchView (CLGeocoder-based place/address search sheet)
│   ├── SavedPinsView (list of persisted pins with navigate/delete)
│   ├── SavedOverlaysView (list of persisted overlays)
│   ├── SettingsView (API key config, Google Sign-In)
│   ├── SignInView (Google Sign-In icon button)
│   └── ImagePicker (PHPickerViewController wrapper)
├── MapOverlayViewModel (state: image, opacity, rotation, lock, pins)
├── GoogleAuthService (Google Sign-In handling)
├── OverlayStore (local persistence: images + JSON metadata including rotation)
├── PinStore (local persistence: saved_pins.json)
├── SavedOverlay (Codable model: image path, NE/SW coords, opacity, rotation, name, date)
└── SavedPin (Codable model: name, latitude, longitude, date)
```

### How It Works

1. **Alignment mode**: User imports an image -> it floats semi-transparently over the map. User adjusts opacity and rotation via sliders in a collapsible panel, and pans/zooms the **map** to align with the image. The panel can be hidden via a toggle button.
2. **Lock**: Captures the map's visible region as geographic bounds -> creates a `GMSGroundOverlay` pinned to those coordinates with the current rotation (bearing) -> removes the floating image.
3. **Locked mode**: The overlay is a native map layer that pans/zooms with the map. User can adjust opacity and rotation in real time, save, unlock, or remove. Controls expand from a single floating button (left-aligned).
4. **Pins**: User searches for places via the search button -> CLGeocoder resolves addresses -> selecting a result adds a persistent `GMSMarker` to the map. Pins can be managed in the Saved Pins view.

## Dependencies

- [Google Maps SDK for iOS](https://github.com/googlemaps/ios-maps-sdk) (SPM, >= 10.0.0)
- [Google Sign-In for iOS](https://github.com/google/GoogleSignIn-iOS) (SPM, >= 8.0.0)
