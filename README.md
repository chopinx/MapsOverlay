# MapsOverlay

iOS app that lets you overlay any image from your photo library onto Google Maps as a semi-transparent layer. Align the map to match your image, lock it as a geo-anchored overlay, and use Google Maps normally with the layer visible.

## Features

- Import any image from your iPhone photo library
- Adjustable transparency slider (5%-100%)
- Pan and zoom the map to align with your overlay image
- Lock the overlay as a geo-anchored ground layer (moves/scales with the map)
- Unlock to re-adjust alignment
- Save overlays locally for reuse (image + geographic bounds + opacity)
- Browse and load saved overlays
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
├── ContentView (main composition)
│   ├── GoogleMapView (UIViewRepresentable wrapping GMSMapView)
│   ├── OverlayImageView (floating semi-transparent image during alignment)
│   ├── ControlPanelView (import, opacity slider, lock/unlock, save, remove)
│   ├── SettingsView (API key config, Google Sign-In)
│   ├── SignInView (Google Sign-In button)
│   └── SavedOverlaysView (list of persisted overlays)
├── MapOverlayViewModel (state management)
├── GoogleAuthService (Google Sign-In handling)
├── OverlayStore (local persistence: images + JSON metadata)
└── SavedOverlay (Codable data model)
```

### How It Works

1. **Alignment mode**: User imports an image -> it floats semi-transparently over the map. User adjusts opacity and pans/zooms the **map** to align with the image.
2. **Lock**: Captures the map's visible region as geographic bounds -> creates a `GMSGroundOverlay` pinned to those coordinates -> removes the floating image.
3. **Locked mode**: The overlay is a native map layer that pans/zooms with the map. User can adjust opacity, save, unlock, or remove.

## Dependencies

- [Google Maps SDK for iOS](https://github.com/googlemaps/ios-maps-sdk) (SPM, >= 10.0.0)
- [Google Sign-In for iOS](https://github.com/google/GoogleSignIn-iOS) (SPM, >= 8.0.0)
