# MapsOverlay

Overlay any image onto Google Maps, align it with real-world features using corner-based free transform, and lock it as a geo-anchored layer that follows pan/zoom. Available as an **iOS app** and a **browser userscript** for maps.google.com.

## iOS App

### Features

- Import any image from your iPhone photo library
- Adjustable transparency slider (5%-100%)
- Rotate overlay images (-180° to 180°); rotation persists with saved overlays
- Corner-based free transform: drag 4 corners to distort the overlay into an arbitrary quadrilateral
- Pan and zoom the map to align with your overlay image
- Lock the overlay as a geo-anchored ground layer (moves/scales/rotates with the map); free transform is baked into the image at lock time
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
│   ├── FreeTransformOverlayView (corner-draggable overlay with ProjectionTransform via GeometryEffect)
│   ├── ControlPanelView (icons-only, left-aligned, collapsible; opacity/rotation sliders, transform toggle, lock/unlock/save/remove)
│   ├── PlaceSearchView (CLGeocoder-based place/address search sheet)
│   ├── SavedPinsView (list of persisted pins with navigate/delete)
│   ├── SavedOverlaysView (list of persisted overlays)
│   ├── SettingsView (API key config, Google Sign-In)
│   ├── SignInView (Google Sign-In icon button)
│   └── ImagePicker (PHPickerViewController wrapper)
├── MapOverlayViewModel (state: image, opacity, rotation, lock, transform corners, pins)
├── GoogleAuthService (Google Sign-In handling)
├── FreeTransformService (homography computation for preview + CIPerspectiveTransform baking with Metal CIContext)
├── OverlayStore (local persistence: images + JSON metadata including rotation)
├── PinStore (local persistence: saved_pins.json)
├── SavedOverlay (Codable model: image path, NE/SW coords, opacity, rotation, name, date)
└── SavedPin (Codable model: name, latitude, longitude, date)
```

### How It Works

1. **Alignment mode**: User imports an image -> it floats semi-transparently over the map. User adjusts opacity and rotation via sliders in a collapsible panel, and pans/zooms the **map** to align with the image. Optional: tap the transform button to enter free transform mode and drag corners to distort the image. The panel can be hidden via a toggle button.
2. **Lock**: If free transform was applied, bakes the perspective distortion into the image via CIPerspectiveTransform. Captures the map's visible region as geographic bounds -> creates a `GMSGroundOverlay` pinned to those coordinates with the current rotation (bearing) -> removes the floating image.
3. **Locked mode**: The overlay is a native map layer that pans/zooms with the map. User can adjust opacity and rotation in real time, save, unlock, or remove. Controls expand from a single floating button (left-aligned).
4. **Pins**: User searches for places via the search button -> CLGeocoder resolves addresses -> selecting a result adds a persistent `GMSMarker` to the map. Pins can be managed in the Saved Pins view.

## Dependencies

- [Google Maps SDK for iOS](https://github.com/googlemaps/ios-maps-sdk) (SPM, >= 10.0.0)
- [Google Sign-In for iOS](https://github.com/google/GoogleSignIn-iOS) (SPM, >= 8.0.0)

---

## Web Version (Tampermonkey Userscript)

A Tampermonkey userscript that adds image overlay functionality directly to maps.google.com — no API key required.

### Features (Web)

- Load any local image as a semi-transparent overlay on Google Maps
- 4 corner drag handles for free-transform (perspective warp to align with map features)
- Adjustable opacity (5%–100%)
- Lock the overlay to geo-coordinates — follows map pan and zoom
- Save and load named overlays locally (browser localStorage)
- Dark theme floating toolbar, collapsible
- Keyboard-accessible corner handles
- Handles antimeridian crossing and map navigation

### Prerequisites (Web)

- Chrome, Firefox, or Edge
- [Tampermonkey](https://www.tampermonkey.net/) browser extension

### Setup (Web)

1. Install [Tampermonkey](https://www.tampermonkey.net/) for your browser
2. Open Tampermonkey dashboard → click "+" to create a new script
3. Paste the contents of `web/map-overlay.user.js` → Save (Ctrl+S)
4. Navigate to [Google Maps](https://www.google.com/maps)
5. The "Overlay" toolbar appears in the top-left corner

### Usage (Web)

1. Click **Load Image** → select an image from your computer
2. Drag the **4 corner handles** to warp and align the image with map features
3. Adjust **opacity** with the slider
4. Click **Lock** to geo-anchor the overlay — it will follow map pan and zoom
5. Click **Save** to persist the overlay in your browser
6. Click **Saved** to browse and load previously saved overlays
7. Click **Unlock** to return to alignment mode
8. Click **Remove** to clear the overlay

### How It Works (Web)

1. **Alignment mode**: Image floats over the map with 4 draggable corner handles. A homography matrix (ported from the iOS `FreeTransformService`) computes a CSS `matrix3d()` transform for real-time perspective rendering.
2. **Lock**: Corner screen positions are converted to lat/lng via Google Maps' projection API. The overlay becomes geo-anchored.
3. **Locked mode**: On every map viewport change (`bounds_changed`, `zoom_changed`), the stored lat/lng corners are re-projected to screen coordinates and the CSS transform is updated. The overlay tracks pan/zoom seamlessly.
4. **Persistence**: Overlays are saved to `localStorage` as base64 image data + 4 geo-corner coordinates + opacity + metadata.
