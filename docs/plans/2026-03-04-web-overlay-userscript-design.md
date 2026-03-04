# MapOverlay Web — Tampermonkey Userscript Design

**Date**: 2026-03-04
**Status**: Approved

## Goal

Port the MapOverlay iOS app's core image overlay feature to a Tampermonkey userscript that runs directly on maps.google.com. Users can load a local image, warp it with 4-corner drag handles to align with map features, lock it as a geo-anchored overlay, and save/load overlays via localStorage.

## Architecture

Single-file Tampermonkey userscript (`map-overlay.user.js`) injected onto maps.google.com.

### Components

```
Tampermonkey Userscript
├── UI Layer (injected HTML/CSS)
│   ├── Floating toolbar (load image, opacity slider, lock/unlock, save/load, remove)
│   └── Corner handles (4 draggable circles on image corners)
├── Transform Engine (JS)
│   ├── Homography matrix computation (ported from iOS FreeTransformService)
│   └── CSS matrix3d for live preview, canvas for baked result
├── Map Integration
│   ├── Access Google Maps instance from page context
│   └── Screen coords ↔ lat/lng conversion via map projection
└── Persistence (localStorage)
    ├── Save: base64 image + 4 corner geo-coords + opacity + metadata
    └── Load: restore overlay from saved entries
```

## User Flow

1. **Load image**: Toolbar button → file picker → image appears centered on map at natural aspect ratio, semi-transparent
2. **Align**: Drag 4 corner handles to warp image. Adjust opacity via slider. Map panning is disabled while dragging corners.
3. **Lock**: Captures 4 corner screen positions → converts to lat/lng via map projection → overlay becomes geo-anchored and follows map pan/zoom
4. **Save**: Stores to localStorage — base64 image data, 4 corner lat/lng pairs, opacity, name, timestamp
5. **Load**: Restores saved overlay, re-pins to geo-coordinates
6. **Unlock**: Returns to alignment mode for re-adjustment

## Technical Details

### Map Instance Access

Google Maps web page exposes the map instance. We use `unsafeWindow` (Tampermonkey API) to access it from the page's JS context. The map object provides:
- `getProjection()` → `fromLatLngToPoint()` / `fromPointToLatLng()` for coordinate conversion
- `getBounds()`, `getZoom()`, `getCenter()` for viewport state
- `addListener('idle', ...)` and `addListener('bounds_changed', ...)` for viewport change events

Fallback: If direct map access fails, use a MutationObserver on the map container's CSS transforms to detect pan/zoom changes, and compute projection from known reference points.

### Perspective Transform (Homography)

Ported from `FreeTransformService.swift`:
- Corner positions stored as normalized [0,1] coordinates relative to image size
- Homography matrix computed from 4 source corners → 4 destination corners
- Live preview: CSS `matrix3d()` transform on an `<img>` element (GPU-accelerated)
- At lock time: no baking needed — we just store the 4 corner geo-coordinates and re-project on every map change

### Locked Overlay Rendering

When locked, on every map viewport change:
1. Convert 4 stored lat/lng corners → screen pixel positions using map projection
2. Compute CSS `matrix3d()` from the image's natural rectangle to the 4 screen positions
3. Apply to the overlay `<img>` element

This means the overlay always renders as a CSS-transformed image — no canvas baking needed for the web version.

### Corner Drag UX

- 4 circular handles (16px diameter) at image corners
- Drag handles with pointer events; map panning disabled during drag (via `pointer-events: none` on map or `event.stopPropagation()`)
- Corner positions clamped to viewport bounds
- Visual feedback: dashed border connecting corners during alignment

### Toolbar UI

Minimal floating toolbar, top-left corner, dark semi-transparent background:
- **Load Image** button (file icon)
- **Opacity** slider (5%–100%)
- **Lock/Unlock** toggle button
- **Save** button (appears when locked)
- **Load Saved** button (opens saved overlays list)
- **Remove** button
- Collapsible via a toggle arrow

## Persistence Schema (localStorage)

Key: `mapOverlay_savedOverlays`

```json
[
  {
    "id": "uuid",
    "name": "My Overlay",
    "imageDataUrl": "data:image/jpeg;base64,...",
    "corners": {
      "topLeft": { "lat": 48.858, "lng": 2.294 },
      "topRight": { "lat": 48.858, "lng": 2.296 },
      "bottomLeft": { "lat": 48.856, "lng": 2.294 },
      "bottomRight": { "lat": 48.856, "lng": 2.296 }
    },
    "opacity": 0.5,
    "createdAt": "2026-03-04T12:00:00Z"
  }
]
```

## Scope

### MVP (In scope)
- Load local image file
- Semi-transparent overlay with opacity control
- 4-corner drag to warp/align
- Lock overlay to geo-coordinates
- Overlay follows map pan/zoom when locked
- Save/load overlays to localStorage
- Remove overlay

### Out of scope
- Rotation slider (corners handle rotation implicitly)
- Pin/search features (Google Maps already has these)
- Multiple simultaneous overlays
- Place boundary rendering
- Export/import overlay files

## Constraints

- localStorage limit: ~5MB per domain on maps.google.com. Large images should be downscaled before storing.
- Google Maps internal API may change without notice. The map instance access strategy needs a robust fallback.
- Tampermonkey `@grant unsafeWindow` required for map instance access.
