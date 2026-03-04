# MapOverlay Web Userscript Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Tampermonkey userscript that adds image overlay, free-transform alignment, geo-locking, and local save/load functionality directly on maps.google.com.

**Architecture:** Single-file userscript injected onto Google Maps web. A floating toolbar provides controls. An `<img>` element overlays the map with CSS `matrix3d()` transforms for perspective distortion. When locked, corner positions are stored as lat/lng and re-projected to screen coords on every map viewport change.

**Tech Stack:** Vanilla JavaScript, CSS, Tampermonkey API (`GM_*`, `unsafeWindow`), Google Maps internal API via page context, localStorage for persistence.

---

### Task 1: Scaffold the Tampermonkey userscript with metadata and injection shell

**Files:**
- Create: `web/map-overlay.user.js`

**Step 1: Create the userscript file with Tampermonkey metadata block and IIFE shell**

```javascript
// ==UserScript==
// @name         MapOverlay
// @namespace    https://github.com/chopinx/MapsOverlay
// @version      0.1.0
// @description  Overlay images on Google Maps with free-transform alignment and geo-locking
// @match        https://www.google.com/maps*
// @match        https://www.google.*/maps*
// @match        https://maps.google.com/*
// @grant        unsafeWindow
// @grant        GM_addStyle
// @run-at       document-idle
// ==/UserScript==

(function () {
  'use strict';

  // ── Constants ──
  const STORAGE_KEY = 'mapOverlay_savedOverlays';
  const MAX_IMAGE_DIMENSION = 2048;
  const HANDLE_SIZE = 16;

  // ── State ──
  const state = {
    image: null,          // HTMLImageElement
    imageDataUrl: null,   // base64 data URL for persistence
    opacity: 0.5,
    isLocked: false,
    // Normalized [0,1] corner positions relative to map container
    corners: {
      topLeft: { x: 0, y: 0 },
      topRight: { x: 1, y: 0 },
      bottomLeft: { x: 0, y: 1 },
      bottomRight: { x: 1, y: 1 },
    },
    // Geo-coordinates of corners when locked
    geoCorners: null,
    savedOverlays: [],
  };

  console.log('[MapOverlay] Userscript loaded, waiting for map...');
})();
```

**Step 2: Verify the file is valid JS syntax**

Run: `node -c web/map-overlay.user.js`
Expected: No errors

**Step 3: Commit**

```bash
git add web/map-overlay.user.js
git commit -m "feat(web): scaffold Tampermonkey userscript with metadata and state"
```

---

### Task 2: Add CSS styles and floating toolbar UI

**Files:**
- Modify: `web/map-overlay.user.js`

**Step 1: Add the GM_addStyle call with all CSS, and the toolbar creation function**

Insert after the `state` object, before the closing `})();`:

```javascript
  // ── Styles ──
  GM_addStyle(`
    #mo-toolbar {
      position: fixed;
      top: 10px;
      left: 10px;
      z-index: 10001;
      display: flex;
      flex-direction: column;
      gap: 6px;
      background: rgba(32,33,36,0.85);
      backdrop-filter: blur(8px);
      border-radius: 12px;
      padding: 8px;
      box-shadow: 0 2px 12px rgba(0,0,0,0.3);
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      font-size: 13px;
      color: #e8eaed;
      user-select: none;
      transition: opacity 0.2s;
    }
    #mo-toolbar.mo-collapsed > *:not(#mo-toggle-btn) { display: none; }
    #mo-toolbar button {
      background: rgba(255,255,255,0.1);
      border: none;
      color: #e8eaed;
      border-radius: 8px;
      padding: 8px 12px;
      cursor: pointer;
      font-size: 13px;
      transition: background 0.15s;
      white-space: nowrap;
    }
    #mo-toolbar button:hover { background: rgba(255,255,255,0.2); }
    #mo-toolbar button.mo-active { background: rgba(66,133,244,0.5); }
    #mo-toolbar button.mo-danger:hover { background: rgba(234,67,53,0.4); }
    #mo-toolbar .mo-slider-row {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 2px 4px;
    }
    #mo-toolbar .mo-slider-row label {
      font-size: 11px;
      min-width: 50px;
      color: #9aa0a6;
    }
    #mo-toolbar input[type="range"] {
      width: 100px;
      accent-color: #8ab4f8;
    }
    #mo-toolbar .mo-btn-row {
      display: flex;
      gap: 4px;
    }
    #mo-overlay-img {
      position: absolute;
      top: 0;
      left: 0;
      transform-origin: 0 0;
      pointer-events: none;
      z-index: 10000;
    }
    .mo-handle {
      position: absolute;
      width: ${HANDLE_SIZE}px;
      height: ${HANDLE_SIZE}px;
      background: white;
      border: 2px solid #4285f4;
      border-radius: 50%;
      cursor: grab;
      z-index: 10002;
      transform: translate(-50%, -50%);
      box-shadow: 0 1px 4px rgba(0,0,0,0.3);
      touch-action: none;
    }
    .mo-handle:active { cursor: grabbing; background: #e8f0fe; }
    #mo-saved-panel {
      position: fixed;
      top: 10px;
      left: 220px;
      z-index: 10003;
      background: rgba(32,33,36,0.92);
      backdrop-filter: blur(8px);
      border-radius: 12px;
      padding: 12px;
      color: #e8eaed;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      font-size: 13px;
      max-height: 400px;
      overflow-y: auto;
      min-width: 200px;
      box-shadow: 0 2px 12px rgba(0,0,0,0.3);
      display: none;
    }
    #mo-saved-panel .mo-saved-item {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 6px 4px;
      border-bottom: 1px solid rgba(255,255,255,0.1);
      cursor: pointer;
    }
    #mo-saved-panel .mo-saved-item:hover { background: rgba(255,255,255,0.08); border-radius: 6px; }
    #mo-saved-panel .mo-saved-item .mo-delete-btn {
      background: none;
      border: none;
      color: #ea4335;
      cursor: pointer;
      font-size: 14px;
      padding: 2px 6px;
    }
  `);

  // ── UI Creation ──
  function createToolbar() {
    const toolbar = document.createElement('div');
    toolbar.id = 'mo-toolbar';
    toolbar.innerHTML = `
      <button id="mo-toggle-btn" title="Toggle toolbar">&#x1f5fa; Overlay</button>
      <button id="mo-load-btn">Load Image</button>
      <div class="mo-slider-row">
        <label>Opacity</label>
        <input type="range" id="mo-opacity" min="5" max="100" value="50">
      </div>
      <div class="mo-btn-row">
        <button id="mo-lock-btn">Lock</button>
        <button id="mo-save-btn" style="display:none">Save</button>
      </div>
      <div class="mo-btn-row">
        <button id="mo-saved-btn">Saved</button>
        <button id="mo-remove-btn" class="mo-danger">Remove</button>
      </div>
      <input type="file" id="mo-file-input" accept="image/*" style="display:none">
    `;
    document.body.appendChild(toolbar);

    // Saved overlays panel
    const savedPanel = document.createElement('div');
    savedPanel.id = 'mo-saved-panel';
    savedPanel.innerHTML = '<strong>Saved Overlays</strong><div id="mo-saved-list"></div>';
    document.body.appendChild(savedPanel);

    return toolbar;
  }
```

**Step 2: Verify syntax**

Run: `node -c web/map-overlay.user.js`
Expected: No errors

**Step 3: Commit**

```bash
git add web/map-overlay.user.js
git commit -m "feat(web): add CSS styles and floating toolbar UI"
```

---

### Task 3: Add map instance discovery and projection utilities

**Files:**
- Modify: `web/map-overlay.user.js`

**Step 1: Add the map discovery and coordinate conversion functions**

Insert after `createToolbar()`:

```javascript
  // ── Map Instance Discovery ──
  let mapInstance = null;
  let mapContainer = null;

  function findMapInstance() {
    // Strategy 1: Look for the map canvas container and its __gm property
    const candidates = document.querySelectorAll('[__gm]');
    if (candidates.length > 0) {
      mapInstance = candidates[0].__gm;
      mapContainer = candidates[0];
      return true;
    }

    // Strategy 2: Search through iframes and known DOM structures
    const mapDiv = document.querySelector('#scene');
    if (mapDiv) {
      mapContainer = mapDiv;
    }

    // Strategy 3: Hook into Google Maps by looking for the map div with .gm-style
    const gmStyle = document.querySelector('.gm-style');
    if (gmStyle) {
      mapContainer = gmStyle;
      // Try to find the map object via the parent element's properties
      let el = gmStyle;
      while (el) {
        if (el.__gm && el.__gm.get) {
          mapInstance = el.__gm;
          return true;
        }
        // Check for google.maps.Map instances stored on elements
        for (const key of Object.keys(el)) {
          if (key.startsWith('__') && el[key] && typeof el[key].getZoom === 'function') {
            mapInstance = el[key];
            return true;
          }
        }
        el = el.parentElement;
      }
    }

    return false;
  }

  // ── Coordinate Conversion ──
  // Fallback: use viewport-relative estimation when map instance not available
  function screenToLatLng(x, y) {
    if (mapInstance && typeof mapInstance.getProjection === 'function') {
      const projection = mapInstance.getProjection();
      const bounds = mapInstance.getBounds();
      const topRight = projection.fromLatLngToPoint(bounds.getNorthEast());
      const bottomLeft = projection.fromLatLngToPoint(bounds.getSouthWest());
      const scale = Math.pow(2, mapInstance.getZoom());
      const worldPoint = new unsafeWindow.google.maps.Point(
        bottomLeft.x + (x / mapContainer.clientWidth) * (topRight.x - bottomLeft.x),
        topRight.y + (y / mapContainer.clientHeight) * (bottomLeft.y - topRight.y)
      );
      return projection.fromPointToLatLng(worldPoint);
    }
    // Fallback: extract from URL
    return extractCenterFromUrl();
  }

  function latLngToScreen(latLng) {
    if (mapInstance && typeof mapInstance.getProjection === 'function') {
      const projection = mapInstance.getProjection();
      const bounds = mapInstance.getBounds();
      const topRight = projection.fromLatLngToPoint(bounds.getNorthEast());
      const bottomLeft = projection.fromLatLngToPoint(bounds.getSouthWest());
      const scale = Math.pow(2, mapInstance.getZoom());
      const worldPoint = projection.fromLatLngToPoint(latLng);
      const x = (worldPoint.x - bottomLeft.x) / (topRight.x - bottomLeft.x) * mapContainer.clientWidth;
      const y = (worldPoint.y - topRight.y) / (bottomLeft.y - topRight.y) * mapContainer.clientHeight;
      return { x, y };
    }
    return null;
  }

  function extractCenterFromUrl() {
    const match = window.location.href.match(/@(-?\d+\.\d+),(-?\d+\.\d+)/);
    if (match) {
      return { lat: parseFloat(match[1]), lng: parseFloat(match[2]) };
    }
    return { lat: 0, lng: 0 };
  }
```

**Step 2: Verify syntax**

Run: `node -c web/map-overlay.user.js`
Expected: No errors

**Step 3: Commit**

```bash
git add web/map-overlay.user.js
git commit -m "feat(web): add map instance discovery and projection utilities"
```

---

### Task 4: Add image loading and overlay rendering

**Files:**
- Modify: `web/map-overlay.user.js`

**Step 1: Add image loading, downscaling, and overlay element creation**

Insert after the coordinate conversion functions:

```javascript
  // ── Image Loading ──
  function loadImageFile(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = (e) => {
        const img = new Image();
        img.onload = () => {
          // Downscale if too large
          const maxDim = MAX_IMAGE_DIMENSION;
          if (img.width > maxDim || img.height > maxDim) {
            const canvas = document.createElement('canvas');
            const scale = maxDim / Math.max(img.width, img.height);
            canvas.width = Math.round(img.width * scale);
            canvas.height = Math.round(img.height * scale);
            const ctx = canvas.getContext('2d');
            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
            const downscaledUrl = canvas.toDataURL('image/jpeg', 0.85);
            const downscaledImg = new Image();
            downscaledImg.onload = () => {
              state.imageDataUrl = downscaledUrl;
              resolve(downscaledImg);
            };
            downscaledImg.src = downscaledUrl;
          } else {
            state.imageDataUrl = e.target.result;
            resolve(img);
          }
        };
        img.onerror = reject;
        img.src = e.target.result;
      };
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
  }

  // ── Overlay Rendering ──
  let overlayImg = null;
  let handles = [];

  function createOverlayElement() {
    if (overlayImg) overlayImg.remove();
    handles.forEach(h => h.remove());
    handles = [];

    if (!mapContainer || !state.image) return;

    overlayImg = document.createElement('img');
    overlayImg.id = 'mo-overlay-img';
    overlayImg.src = state.image.src;
    mapContainer.style.position = 'relative';
    mapContainer.appendChild(overlayImg);

    // Position image at natural aspect ratio, centered in the map container
    const containerW = mapContainer.clientWidth;
    const containerH = mapContainer.clientHeight;
    const imgW = state.image.naturalWidth;
    const imgH = state.image.naturalHeight;
    const scale = Math.min(
      (containerW * 0.6) / imgW,
      (containerH * 0.6) / imgH,
      1
    );
    const displayW = imgW * scale;
    const displayH = imgH * scale;
    const offsetX = (containerW - displayW) / 2;
    const offsetY = (containerH - displayH) / 2;

    // Set initial corners based on centered image position (normalized)
    state.corners = {
      topLeft: { x: offsetX / containerW, y: offsetY / containerH },
      topRight: { x: (offsetX + displayW) / containerW, y: offsetY / containerH },
      bottomLeft: { x: offsetX / containerW, y: (offsetY + displayH) / containerH },
      bottomRight: { x: (offsetX + displayW) / containerW, y: (offsetY + displayH) / containerH },
    };

    // Create corner handles
    for (const key of ['topLeft', 'topRight', 'bottomLeft', 'bottomRight']) {
      const handle = document.createElement('div');
      handle.className = 'mo-handle';
      handle.dataset.corner = key;
      mapContainer.appendChild(handle);
      handles.push(handle);
      setupHandleDrag(handle, key);
    }

    updateOverlayTransform();
  }

  function removeOverlayElement() {
    if (overlayImg) { overlayImg.remove(); overlayImg = null; }
    handles.forEach(h => h.remove());
    handles = [];
    state.image = null;
    state.imageDataUrl = null;
    state.isLocked = false;
    state.geoCorners = null;
    state.corners = {
      topLeft: { x: 0, y: 0 },
      topRight: { x: 1, y: 0 },
      bottomLeft: { x: 0, y: 1 },
      bottomRight: { x: 1, y: 1 },
    };
    updateToolbarState();
  }
```

**Step 2: Verify syntax**

Run: `node -c web/map-overlay.user.js`
Expected: No errors

**Step 3: Commit**

```bash
git add web/map-overlay.user.js
git commit -m "feat(web): add image loading, downscaling, and overlay element creation"
```

---

### Task 5: Add homography computation and CSS matrix3d transform

**Files:**
- Modify: `web/map-overlay.user.js`

**Step 1: Port the homography math from iOS and add the CSS matrix3d renderer**

Insert after `removeOverlayElement()`:

```javascript
  // ── Homography & Transform ──
  // Ported from iOS FreeTransformService.swift
  // Maps a unit square (0,0)-(1,0)-(1,1)-(0,1) to arbitrary quad (tl, tr, br, bl)
  function computeHomographyMatrix(tl, tr, br, bl) {
    // Source: unit square corners (0,0), (1,0), (1,1), (0,1)
    // We solve for the 3x3 matrix H such that H * src = dst (in homogeneous coords)
    const sA = tr.x - br.x;
    const sB = bl.x - br.x;
    const sC = br.x - tr.x - bl.x + tl.x;
    const sD = tr.y - br.y;
    const sE = bl.y - br.y;
    const sF = br.y - tr.y - bl.y + tl.y;

    const det = sA * sE - sB * sD;
    if (Math.abs(det) < 1e-10) return null;

    const g = (sC * sE - sB * sF) / det;
    const h = (sA * sF - sC * sD) / det;

    const a = tr.x * (1 + g) - tl.x;
    const b = bl.x * (1 + h) - tl.x;
    const c = tl.x;
    const d = tr.y * (1 + g) - tl.y;
    const e = bl.y * (1 + h) - tl.y;
    const f = tl.y;

    // CSS matrix3d uses column-major order for a 4x4 matrix
    // We need to map from the image's pixel space to screen space
    // The 2D homography [a b c; d e f; g h 1] becomes a 4x4 matrix:
    return [
      a, d, 0, g,
      b, e, 0, h,
      0, 0, 1, 0,
      c, f, 0, 1,
    ];
  }

  function updateOverlayTransform() {
    if (!overlayImg || !state.image || !mapContainer) return;

    const cw = mapContainer.clientWidth;
    const ch = mapContainer.clientHeight;
    const imgW = state.image.naturalWidth;
    const imgH = state.image.naturalHeight;

    // Corner positions in screen pixels
    let tl, tr, bl, br;

    if (state.isLocked && state.geoCorners) {
      // Convert geo-coordinates back to screen positions
      const tlScreen = latLngToScreen(state.geoCorners.topLeft);
      const trScreen = latLngToScreen(state.geoCorners.topRight);
      const blScreen = latLngToScreen(state.geoCorners.bottomLeft);
      const brScreen = latLngToScreen(state.geoCorners.bottomRight);
      if (!tlScreen || !trScreen || !blScreen || !brScreen) return;
      tl = tlScreen; tr = trScreen; bl = blScreen; br = brScreen;
    } else {
      tl = { x: state.corners.topLeft.x * cw, y: state.corners.topLeft.y * ch };
      tr = { x: state.corners.topRight.x * cw, y: state.corners.topRight.y * ch };
      bl = { x: state.corners.bottomLeft.x * cw, y: state.corners.bottomLeft.y * ch };
      br = { x: state.corners.bottomRight.x * cw, y: state.corners.bottomRight.y * ch };
    }

    // Compute homography from image natural size rect to screen quad
    // First normalize: map (0,0)-(imgW,0)-(imgW,imgH)-(0,imgH) to tl,tr,br,bl
    // We work in screen pixel space. The <img> is rendered at natural size,
    // so we compute the matrix that maps (0,0)→tl, (imgW,0)→tr, (imgW,imgH)→br, (0,imgH)→bl
    const matrix = computeHomographyMatrix(
      { x: tl.x / imgW, y: tl.y / imgH },
      { x: tr.x / imgW, y: tr.y / imgH },
      { x: br.x / imgW, y: br.y / imgH },
      { x: bl.x / imgW, y: bl.y / imgH }
    );

    if (!matrix) return;

    // Scale the matrix to work with the actual image pixel dimensions
    // The img element renders at naturalWidth x naturalHeight
    overlayImg.style.width = imgW + 'px';
    overlayImg.style.height = imgH + 'px';
    overlayImg.style.opacity = state.opacity;

    // Apply CSS matrix3d
    overlayImg.style.transform = `matrix3d(${matrix.join(',')})`;

    // Update handle positions
    const corners = { topLeft: tl, topRight: tr, bottomLeft: bl, bottomRight: br };
    handles.forEach(handle => {
      const key = handle.dataset.corner;
      const pos = corners[key];
      handle.style.left = pos.x + 'px';
      handle.style.top = pos.y + 'px';
      handle.style.display = state.isLocked ? 'none' : 'block';
    });
  }
```

**Step 2: Verify syntax**

Run: `node -c web/map-overlay.user.js`
Expected: No errors

**Step 3: Commit**

```bash
git add web/map-overlay.user.js
git commit -m "feat(web): add homography computation and CSS matrix3d transform"
```

---

### Task 6: Add corner handle drag interaction

**Files:**
- Modify: `web/map-overlay.user.js`

**Step 1: Add the drag handler for corner handles**

Insert after `updateOverlayTransform()`:

```javascript
  // ── Corner Handle Drag ──
  function setupHandleDrag(handle, cornerKey) {
    let dragging = false;

    handle.addEventListener('pointerdown', (e) => {
      if (state.isLocked) return;
      dragging = true;
      handle.setPointerCapture(e.pointerId);
      e.stopPropagation();
      e.preventDefault();
    });

    handle.addEventListener('pointermove', (e) => {
      if (!dragging || !mapContainer) return;
      e.stopPropagation();
      e.preventDefault();

      const rect = mapContainer.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;

      // Clamp to container bounds, normalized
      state.corners[cornerKey] = {
        x: Math.max(0, Math.min(1, x / rect.width)),
        y: Math.max(0, Math.min(1, y / rect.height)),
      };

      updateOverlayTransform();
    });

    handle.addEventListener('pointerup', (e) => {
      dragging = false;
      handle.releasePointerCapture(e.pointerId);
    });

    handle.addEventListener('lostpointercapture', () => {
      dragging = false;
    });
  }
```

**Step 2: Verify syntax**

Run: `node -c web/map-overlay.user.js`
Expected: No errors

**Step 3: Commit**

```bash
git add web/map-overlay.user.js
git commit -m "feat(web): add corner handle drag interaction"
```

---

### Task 7: Add lock/unlock with geo-anchoring and map viewport tracking

**Files:**
- Modify: `web/map-overlay.user.js`

**Step 1: Add lock, unlock, and map change listener functions**

Insert after `setupHandleDrag`:

```javascript
  // ── Lock / Unlock ──
  function lockOverlay() {
    if (!state.image || !mapContainer) return;

    const cw = mapContainer.clientWidth;
    const ch = mapContainer.clientHeight;

    // Convert current corner screen positions to geo-coordinates
    const geoCorners = {};
    for (const key of ['topLeft', 'topRight', 'bottomLeft', 'bottomRight']) {
      const sx = state.corners[key].x * cw;
      const sy = state.corners[key].y * ch;
      const latLng = screenToLatLng(sx, sy);
      if (!latLng) {
        console.warn('[MapOverlay] Cannot lock: projection unavailable');
        return;
      }
      geoCorners[key] = latLng;
    }

    state.geoCorners = geoCorners;
    state.isLocked = true;
    updateOverlayTransform();
    updateToolbarState();
    startMapChangeListener();
  }

  function unlockOverlay() {
    if (!state.image || !mapContainer) return;

    // Convert geo-coordinates back to current screen positions
    const cw = mapContainer.clientWidth;
    const ch = mapContainer.clientHeight;
    if (state.geoCorners) {
      for (const key of ['topLeft', 'topRight', 'bottomLeft', 'bottomRight']) {
        const screen = latLngToScreen(state.geoCorners[key]);
        if (screen) {
          state.corners[key] = {
            x: screen.x / cw,
            y: screen.y / ch,
          };
        }
      }
    }

    state.isLocked = false;
    state.geoCorners = null;
    updateOverlayTransform();
    updateToolbarState();
    stopMapChangeListener();
  }

  // ── Map Change Listener ──
  let mapChangeListeners = [];
  let rafId = null;

  function startMapChangeListener() {
    stopMapChangeListener();

    if (mapInstance && typeof mapInstance.addListener === 'function') {
      // Use Google Maps events if map instance available
      mapChangeListeners.push(
        mapInstance.addListener('bounds_changed', () => {
          if (rafId) cancelAnimationFrame(rafId);
          rafId = requestAnimationFrame(updateOverlayTransform);
        })
      );
      mapChangeListeners.push(
        mapInstance.addListener('zoom_changed', () => {
          if (rafId) cancelAnimationFrame(rafId);
          rafId = requestAnimationFrame(updateOverlayTransform);
        })
      );
    } else {
      // Fallback: MutationObserver on transform changes
      const observer = new MutationObserver(() => {
        if (rafId) cancelAnimationFrame(rafId);
        rafId = requestAnimationFrame(updateOverlayTransform);
      });
      if (mapContainer) {
        observer.observe(mapContainer, {
          attributes: true,
          attributeFilter: ['style'],
          subtree: true,
        });
      }
      mapChangeListeners.push({ remove: () => observer.disconnect() });
    }
  }

  function stopMapChangeListener() {
    mapChangeListeners.forEach(l => {
      if (typeof l.remove === 'function') l.remove();
      else if (typeof l === 'function') l();
    });
    mapChangeListeners = [];
    if (rafId) { cancelAnimationFrame(rafId); rafId = null; }
  }
```

**Step 2: Verify syntax**

Run: `node -c web/map-overlay.user.js`
Expected: No errors

**Step 3: Commit**

```bash
git add web/map-overlay.user.js
git commit -m "feat(web): add lock/unlock with geo-anchoring and map viewport tracking"
```

---

### Task 8: Add localStorage persistence (save/load/delete overlays)

**Files:**
- Modify: `web/map-overlay.user.js`

**Step 1: Add save, load, delete, and render saved list functions**

Insert after `stopMapChangeListener`:

```javascript
  // ── Persistence ──
  function saveOverlay() {
    if (!state.isLocked || !state.geoCorners || !state.imageDataUrl) return;

    const name = prompt('Name this overlay:', 'Overlay ' + (state.savedOverlays.length + 1));
    if (!name) return;

    const entry = {
      id: crypto.randomUUID(),
      name: name,
      imageDataUrl: state.imageDataUrl,
      corners: JSON.parse(JSON.stringify(state.geoCorners)),
      opacity: state.opacity,
      createdAt: new Date().toISOString(),
    };

    state.savedOverlays.push(entry);
    persistOverlays();
    updateToolbarState();
  }

  function loadSavedOverlay(entry) {
    const img = new Image();
    img.onload = () => {
      state.image = img;
      state.imageDataUrl = entry.imageDataUrl;
      state.opacity = entry.opacity;
      state.geoCorners = JSON.parse(JSON.stringify(entry.corners));
      state.isLocked = true;

      createOverlayElement();
      // Override corners — we're locked so geoCorners is used
      state.isLocked = true;
      updateOverlayTransform();
      updateToolbarState();
      startMapChangeListener();

      // Hide saved panel
      document.getElementById('mo-saved-panel').style.display = 'none';
    };
    img.src = entry.imageDataUrl;
  }

  function deleteSavedOverlay(id) {
    state.savedOverlays = state.savedOverlays.filter(o => o.id !== id);
    persistOverlays();
    renderSavedList();
  }

  function persistOverlays() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state.savedOverlays));
    } catch (e) {
      console.error('[MapOverlay] Failed to save:', e);
      alert('Failed to save overlay. Storage may be full.');
    }
  }

  function loadPersistedOverlays() {
    try {
      const data = localStorage.getItem(STORAGE_KEY);
      if (data) {
        state.savedOverlays = JSON.parse(data);
      }
    } catch (e) {
      console.error('[MapOverlay] Failed to load saved overlays:', e);
      state.savedOverlays = [];
    }
  }

  function renderSavedList() {
    const list = document.getElementById('mo-saved-list');
    if (!list) return;
    list.innerHTML = '';
    if (state.savedOverlays.length === 0) {
      list.innerHTML = '<p style="color:#9aa0a6;padding:8px 0;">No saved overlays</p>';
      return;
    }
    for (const entry of state.savedOverlays) {
      const item = document.createElement('div');
      item.className = 'mo-saved-item';
      const nameSpan = document.createElement('span');
      nameSpan.textContent = entry.name;
      nameSpan.style.cursor = 'pointer';
      nameSpan.addEventListener('click', () => loadSavedOverlay(entry));
      const deleteBtn = document.createElement('button');
      deleteBtn.className = 'mo-delete-btn';
      deleteBtn.textContent = '✕';
      deleteBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        if (confirm(`Delete "${entry.name}"?`)) {
          deleteSavedOverlay(entry.id);
        }
      });
      item.appendChild(nameSpan);
      item.appendChild(deleteBtn);
      list.appendChild(item);
    }
  }
```

**Step 2: Verify syntax**

Run: `node -c web/map-overlay.user.js`
Expected: No errors

**Step 3: Commit**

```bash
git add web/map-overlay.user.js
git commit -m "feat(web): add localStorage persistence for save/load/delete overlays"
```

---

### Task 9: Wire up toolbar event handlers and toolbar state management

**Files:**
- Modify: `web/map-overlay.user.js`

**Step 1: Add event wiring and toolbar state update function**

Insert after `renderSavedList`:

```javascript
  // ── Toolbar State ──
  function updateToolbarState() {
    const lockBtn = document.getElementById('mo-lock-btn');
    const saveBtn = document.getElementById('mo-save-btn');
    const loadBtn = document.getElementById('mo-load-btn');
    const removeBtn = document.getElementById('mo-remove-btn');

    if (lockBtn) {
      lockBtn.textContent = state.isLocked ? 'Unlock' : 'Lock';
      lockBtn.className = state.isLocked ? 'mo-active' : '';
      lockBtn.style.display = state.image ? '' : 'none';
    }
    if (saveBtn) {
      saveBtn.style.display = state.isLocked ? '' : 'none';
    }
    if (loadBtn) {
      loadBtn.style.display = state.image ? 'none' : '';
    }
    if (removeBtn) {
      removeBtn.style.display = state.image ? '' : 'none';
    }

    const opacityRow = document.querySelector('#mo-toolbar .mo-slider-row');
    if (opacityRow) {
      opacityRow.style.display = state.image ? '' : 'none';
    }
  }

  // ── Event Wiring ──
  function wireEvents() {
    const fileInput = document.getElementById('mo-file-input');
    const loadBtn = document.getElementById('mo-load-btn');
    const lockBtn = document.getElementById('mo-lock-btn');
    const saveBtn = document.getElementById('mo-save-btn');
    const savedBtn = document.getElementById('mo-saved-btn');
    const removeBtn = document.getElementById('mo-remove-btn');
    const opacitySlider = document.getElementById('mo-opacity');
    const toggleBtn = document.getElementById('mo-toggle-btn');
    const savedPanel = document.getElementById('mo-saved-panel');

    loadBtn.addEventListener('click', () => fileInput.click());

    fileInput.addEventListener('change', async (e) => {
      const file = e.target.files[0];
      if (!file) return;
      try {
        state.image = await loadImageFile(file);
        state.isLocked = false;
        state.geoCorners = null;
        createOverlayElement();
        updateToolbarState();
      } catch (err) {
        console.error('[MapOverlay] Image load failed:', err);
        alert('Failed to load image');
      }
      fileInput.value = '';
    });

    lockBtn.addEventListener('click', () => {
      if (state.isLocked) {
        unlockOverlay();
      } else {
        lockOverlay();
      }
    });

    saveBtn.addEventListener('click', saveOverlay);

    savedBtn.addEventListener('click', () => {
      const visible = savedPanel.style.display === 'block';
      savedPanel.style.display = visible ? 'none' : 'block';
      if (!visible) renderSavedList();
    });

    removeBtn.addEventListener('click', () => {
      if (confirm('Remove the current overlay?')) {
        stopMapChangeListener();
        removeOverlayElement();
      }
    });

    opacitySlider.addEventListener('input', (e) => {
      state.opacity = parseInt(e.target.value) / 100;
      if (overlayImg) overlayImg.style.opacity = state.opacity;
    });

    toggleBtn.addEventListener('click', () => {
      const toolbar = document.getElementById('mo-toolbar');
      toolbar.classList.toggle('mo-collapsed');
    });
  }
```

**Step 2: Verify syntax**

Run: `node -c web/map-overlay.user.js`
Expected: No errors

**Step 3: Commit**

```bash
git add web/map-overlay.user.js
git commit -m "feat(web): wire toolbar event handlers and state management"
```

---

### Task 10: Add initialization with retry logic and boot the userscript

**Files:**
- Modify: `web/map-overlay.user.js`

**Step 1: Add the init function with map discovery retry, and the boot call**

Insert after `wireEvents`, just before the closing `})();`:

```javascript
  // ── Initialization ──
  function init() {
    loadPersistedOverlays();
    createToolbar();
    wireEvents();
    updateToolbarState();

    // Try to find the map instance with retries (Google Maps loads asynchronously)
    let attempts = 0;
    const maxAttempts = 30;
    const retryInterval = setInterval(() => {
      attempts++;
      if (findMapInstance()) {
        console.log('[MapOverlay] Map instance found after', attempts, 'attempts');
        // Also find the map container if not set
        if (!mapContainer) {
          mapContainer = document.querySelector('.gm-style') || document.querySelector('#scene');
        }
        clearInterval(retryInterval);
      } else if (attempts >= maxAttempts) {
        console.warn('[MapOverlay] Map instance not found after', maxAttempts, 'attempts. Overlay will work without geo-locking.');
        // Still set mapContainer for overlay positioning
        mapContainer = document.querySelector('.gm-style') || document.querySelector('#scene') || document.querySelector('#content-container');
        clearInterval(retryInterval);
      }
    }, 1000);
  }

  // Boot
  if (document.readyState === 'complete') {
    init();
  } else {
    window.addEventListener('load', init);
  }
```

**Step 2: Verify the complete file has valid syntax**

Run: `node -c web/map-overlay.user.js`
Expected: No errors

**Step 3: Commit**

```bash
git add web/map-overlay.user.js
git commit -m "feat(web): add initialization with retry and boot sequence"
```

---

### Task 11: Manual testing on maps.google.com

**Files:**
- Read: `web/map-overlay.user.js`

**Step 1: Install in Tampermonkey**

1. Open Tampermonkey dashboard in Chrome
2. Click "+" to create new script
3. Paste contents of `web/map-overlay.user.js`
4. Save (Ctrl+S)

**Step 2: Test on Google Maps**

1. Navigate to https://www.google.com/maps
2. Verify the "Overlay" toolbar appears in top-left
3. Click "Load Image" → select a local image
4. Verify image appears semi-transparent, centered, with 4 corner handles
5. Drag corners to warp the image
6. Adjust opacity slider
7. Click "Lock" → verify handles disappear
8. Pan/zoom the map → verify overlay follows
9. Click "Unlock" → verify handles return at correct positions
10. Click "Lock" again → click "Save" → enter a name
11. Click "Remove" → overlay disappears
12. Click "Saved" → verify the saved overlay appears in the list
13. Click the saved overlay name → verify it loads and locks correctly
14. Refresh the page → click "Saved" → verify persistence works

**Step 3: Fix any issues found during testing**

Iterate on the script based on test results. The most likely issues:
- Map instance discovery may need adjustment for Google Maps' current DOM structure
- CSS matrix3d computation may need sign/order fixes for correct perspective rendering
- Handle z-index may need tuning to stay above Google Maps UI elements

**Step 4: Commit fixes**

```bash
git add web/map-overlay.user.js
git commit -m "fix(web): address issues from manual testing"
```

---

### Task 12: Update README and finalize

**Files:**
- Modify: `README.md`

**Step 1: Add web userscript section to README**

Add a new section after the existing iOS content:

```markdown
## Web Version (Tampermonkey Userscript)

A Tampermonkey userscript that adds image overlay functionality directly to maps.google.com.

### Features (Web)

- Load any local image as a semi-transparent overlay on Google Maps
- Drag 4 corner handles to warp/align the image with map features
- Adjustable opacity (5%–100%)
- Lock the overlay to geo-coordinates — it follows map pan/zoom
- Save and load overlays locally (browser localStorage)

### Setup (Web)

1. Install [Tampermonkey](https://www.tampermonkey.net/) browser extension
2. Open Tampermonkey dashboard → "+" → paste `web/map-overlay.user.js` → Save
3. Navigate to [Google Maps](https://www.google.com/maps)
4. The "Overlay" toolbar appears in the top-left corner

### Usage (Web)

1. Click **Load Image** → select an image from your computer
2. Drag the **corner handles** to align the image with map features
3. Adjust **opacity** with the slider
4. Click **Lock** to geo-anchor the overlay (it will follow pan/zoom)
5. Click **Save** to persist the overlay in your browser
6. Click **Saved** to load previously saved overlays
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add web Tampermonkey userscript section to README"
```

---

## Summary

| Task | Description | Estimated Complexity |
|------|-------------|---------------------|
| 1 | Scaffold userscript with metadata and state | Simple |
| 2 | CSS styles and floating toolbar UI | Simple |
| 3 | Map instance discovery and projection | Medium |
| 4 | Image loading and overlay rendering | Medium |
| 5 | Homography computation and CSS matrix3d | Hard (core math) |
| 6 | Corner handle drag interaction | Simple |
| 7 | Lock/unlock with geo-anchoring | Medium |
| 8 | localStorage persistence | Simple |
| 9 | Toolbar event wiring | Simple |
| 10 | Initialization with retry boot | Simple |
| 11 | Manual testing on maps.google.com | Medium (iterative) |
| 12 | Update README | Simple |

**Total: 12 tasks, single file (`web/map-overlay.user.js`) + README update**
