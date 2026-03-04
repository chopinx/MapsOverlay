// ==UserScript==
// @name         MapOverlay
// @namespace    https://github.com/chopinx/MapsOverlay
// @version      0.3.0
// @updated      2026-03-04
// @description  Overlay images on Google Maps with free-transform alignment and geo-locking
// @match        https://www.google.com/maps*
// @match        https://www.google.de/maps*
// @match        https://www.google.co.uk/maps*
// @match        https://www.google.co.jp/maps*
// @match        https://www.google.fr/maps*
// @match        https://maps.google.com/*
// @grant        unsafeWindow
// @grant        GM_addStyle
// @run-at       document-idle
// ==/UserScript==

(function () {
  'use strict';

  // ── Safe unsafeWindow reference ──
  const _unsafeWindow = typeof unsafeWindow !== 'undefined' ? unsafeWindow : window;

  // ── Constants ──
  const STORAGE_KEY = 'mapOverlay_savedOverlays';
  const MAX_FILE_SIZE = 20 * 1024 * 1024; // 20 MB
  const MAX_IMAGE_DIMENSION = 4096;
  const MIN_QUAD_AREA_PX = 25; // 5px * 5px — degenerate quad threshold
  const HANDLE_SIZE = 16;

  // ── State ──
  const state = {
    image: null,          // HTMLImageElement
    imageDataUrl: null,   // base64 data URL for persistence
    opacity: 0.5,
    isLocked: false,
    // Corner positions in screen pixels relative to map container
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

  // ── Styles ──
  function addStyle(css) {
    if (typeof GM_addStyle === 'function') {
      GM_addStyle(css);
    } else {
      const style = document.createElement('style');
      style.textContent = css;
      document.head.appendChild(style);
    }
  }

  addStyle(`
    #mo-toolbar {
      position: fixed;
      top: 10px;
      left: 10px;
      z-index: 100001;
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
      z-index: 100000;
    }
    .mo-handle {
      position: absolute;
      width: 16px;
      height: 16px;
      background: white;
      border: 2px solid #4285f4;
      border-radius: 50%;
      cursor: grab;
      z-index: 100002;
      transform: translate(-50%, -50%);
      box-shadow: 0 1px 4px rgba(0,0,0,0.3);
      touch-action: none;
    }
    .mo-handle:active { cursor: grabbing; background: #e8f0fe; }
    #mo-saved-panel {
      position: fixed;
      top: 10px;
      left: 220px;
      z-index: 100003;
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
      <button id="mo-toggle-btn" title="Toggle toolbar">Overlay</button>
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

    const savedPanel = document.createElement('div');
    savedPanel.id = 'mo-saved-panel';
    savedPanel.innerHTML = '<strong>Saved Overlays</strong><div id="mo-saved-list"></div>';
    document.body.appendChild(savedPanel);

    return toolbar;
  }

  // ── Map Instance Discovery ──
  let mapInstance = null;
  let mapContainer = null;

  function findMapContainer() {
    // Google Maps web app DOM selectors, ordered by specificity
    const selectors = [
      '.gm-style',                    // Classic Google Maps JS API
      'div[role="application"]',       // Modern Google Maps web app (2024+)
      '#scene',                        // Older Google Maps layout
      '#content-container',            // Alternative layout
    ];
    for (const sel of selectors) {
      const el = document.querySelector(sel);
      if (el && el.clientWidth > 100 && el.clientHeight > 100) {
        return el;
      }
    }
    // Last resort: find parent of the largest canvas (the map rendering surface)
    let bestCanvas = null;
    let bestArea = 0;
    for (const c of document.querySelectorAll('canvas')) {
      const area = c.width * c.height;
      if (area > bestArea) { bestArea = area; bestCanvas = c; }
    }
    if (bestCanvas && bestCanvas.parentElement) {
      return bestCanvas.parentElement;
    }
    return null;
  }

  function findMapInstance() {
    // First ensure we have a map container
    if (!mapContainer) {
      mapContainer = findMapContainer();
    }

    // Try to find a google.maps.Map instance on DOM elements
    const searchRoots = [
      mapContainer,
      document.querySelector('.gm-style'),
      document.querySelector('div[role="application"]'),
    ].filter(Boolean);

    for (const root of searchRoots) {
      let el = root;
      while (el) {
        try {
          for (const key of Object.keys(el)) {
            try {
              if (el[key] && typeof el[key].getZoom === 'function' && typeof el[key].getProjection === 'function') {
                mapInstance = el[key];
                return true;
              }
            } catch (_) { /* ignore cross-origin errors */ }
          }
        } catch (_) { /* Object.keys can throw on some DOM elements */ }
        el = el.parentElement;
      }
    }

    // Try canvas elements' ancestor chain
    for (const canvas of document.querySelectorAll('canvas')) {
      let el = canvas.parentElement;
      let depth = 0;
      while (el && depth < 10) {
        try {
          for (const key of Object.keys(el)) {
            try {
              if (el[key] && typeof el[key].getZoom === 'function') {
                mapInstance = el[key];
                return true;
              }
            } catch (_) {}
          }
        } catch (_) {}
        el = el.parentElement;
        depth++;
      }
    }

    return false;
  }

  // ── Viewport Parsing ──
  // Google Maps web app stores viewport in the URL as @lat,lng,zoomz
  function getViewport() {
    const match = window.location.href.match(/@(-?\d+\.?\d*),(-?\d+\.?\d*),(\d+\.?\d*)z/);
    if (match) {
      return { lat: parseFloat(match[1]), lng: parseFloat(match[2]), zoom: parseFloat(match[3]) };
    }
    return null;
  }

  // ── Mercator Projection (self-contained, no Google Maps API needed) ──
  // Google Maps uses a Mercator projection with a 256px tile at zoom 0.
  // World coordinates: x = [0, 256], y = [0, 256]

  const TILE_SIZE = 256;

  function latLngToWorld(lat, lng) {
    const siny = Math.sin((lat * Math.PI) / 180);
    // Clamp to avoid infinity at poles
    const clampedSiny = Math.max(-0.9999, Math.min(0.9999, siny));
    return {
      x: TILE_SIZE * (0.5 + lng / 360),
      y: TILE_SIZE * (0.5 - Math.log((1 + clampedSiny) / (1 - clampedSiny)) / (4 * Math.PI)),
    };
  }

  function worldToLatLng(wx, wy) {
    const lng = (wx / TILE_SIZE - 0.5) * 360;
    const latRadians = (0.5 - wy / TILE_SIZE) * 2 * Math.PI;
    const lat = (180 / Math.PI) * Math.atan(Math.sinh(latRadians));
    return { lat, lng };
  }

  function screenToLatLng(x, y) {
    const vp = getViewport();
    if (!vp || !mapContainer) return null;

    const scale = Math.pow(2, vp.zoom);
    const cw = mapContainer.clientWidth;
    const ch = mapContainer.clientHeight;
    const center = latLngToWorld(vp.lat, vp.lng);

    // Screen center is at (cw/2, ch/2), each pixel = 1/scale world units
    const wx = center.x + (x - cw / 2) / scale;
    const wy = center.y + (y - ch / 2) / scale;

    return worldToLatLng(wx, wy);
  }

  function latLngToScreen(latLng) {
    const vp = getViewport();
    if (!vp || !mapContainer) return null;

    const lat = typeof latLng.lat === 'function' ? latLng.lat() : latLng.lat;
    const lng = typeof latLng.lng === 'function' ? latLng.lng() : latLng.lng;

    const scale = Math.pow(2, vp.zoom);
    const cw = mapContainer.clientWidth;
    const ch = mapContainer.clientHeight;
    const center = latLngToWorld(vp.lat, vp.lng);
    const point = latLngToWorld(lat, lng);

    const x = (point.x - center.x) * scale + cw / 2;
    const y = (point.y - center.y) * scale + ch / 2;

    return { x, y };
  }

  // ── Image Loading ──
  function loadImageFile(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = (e) => {
        const img = new Image();
        img.onload = () => {
          if (img.width > MAX_IMAGE_DIMENSION || img.height > MAX_IMAGE_DIMENSION) {
            const canvas = document.createElement('canvas');
            const scale = MAX_IMAGE_DIMENSION / Math.max(img.width, img.height);
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
            downscaledImg.onerror = reject;
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

    // Only reset corners if not loading a locked overlay with geo-corners
    if (!(state.isLocked && state.geoCorners)) {
      const containerW = mapContainer.clientWidth;
      const containerH = mapContainer.clientHeight;
      const imgW = Math.min(state.image.naturalWidth, MAX_IMAGE_DIMENSION);
      const imgH = Math.min(state.image.naturalHeight, MAX_IMAGE_DIMENSION);
      const scale = Math.min(
        (containerW * 0.6) / imgW,
        (containerH * 0.6) / imgH,
        1
      );
      const displayW = imgW * scale;
      const displayH = imgH * scale;
      const offsetX = (containerW - displayW) / 2;
      const offsetY = (containerH - displayH) / 2;

      state.corners = {
        topLeft: { x: offsetX, y: offsetY },
        topRight: { x: offsetX + displayW, y: offsetY },
        bottomLeft: { x: offsetX, y: offsetY + displayH },
        bottomRight: { x: offsetX + displayW, y: offsetY + displayH },
      };
    }

    // Create corner handles
    for (const key of ['topLeft', 'topRight', 'bottomLeft', 'bottomRight']) {
      const handle = document.createElement('div');
      handle.className = 'mo-handle';
      handle.dataset.corner = key;
      handle.setAttribute('tabindex', '0');
      handle.setAttribute('role', 'button');
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

  // ── Homography & Transform ──
  // Ported from iOS FreeTransformService.swift
  // Maps a source rectangle (0,0)-(W,H) to an arbitrary quad (tl, tr, br, bl).
  //
  // Solves: x' = (ax + by + c) / (gx + hy + 1)
  //         y' = (dx + ey + f) / (gx + hy + 1)
  //
  // The iOS code (lines 86-105) computes coefficients a-h for the projective
  // transform from a rect of size W x H to the destination quad.
  // CSS matrix3d uses column-major 4x4, so we construct the appropriate matrix.
  function computeHomography(srcW, srcH, tl, tr, br, bl) {
    if (srcW <= 0 || srcH <= 0) return null;

    // Solve for g, h from the 4th-corner constraint (iOS lines 87-98)
    const sA = srcW * (tr.x - br.x);
    const sB = srcH * (bl.x - br.x);
    const sC = br.x - tr.x - bl.x + tl.x;
    const sD = srcW * (tr.y - br.y);
    const sE = srcH * (bl.y - br.y);
    const sF = br.y - tr.y - bl.y + tl.y;

    const det = sA * sE - sB * sD;
    if (Math.abs(det) < 1e-10) return null;

    const g = (sC * sE - sB * sF) / det;
    const h = (sA * sF - sC * sD) / det;

    // Coefficients (iOS lines 100-105)
    const a = tr.x * g + (tr.x - tl.x) / srcW;
    const b = bl.x * h + (bl.x - tl.x) / srcH;
    const c = tl.x;
    const d = tr.y * g + (tr.y - tl.y) / srcW;
    const e = bl.y * h + (bl.y - tl.y) / srcH;
    const f = tl.y;

    // CSS matrix3d is column-major 4x4.
    // The 2D projective transform [a b c; d e f; g h 1] in column-vector
    // convention maps (sx, sy, 1) -> (x'w, y'w, w).
    // CSS matrix3d(m11,m21,m31,m41, m12,m22,m32,m42, m13,m23,m33,m43, m14,m24,m34,m44)
    // We embed the 3x3 into 4x4 by putting the projective row/col in position 4:
    //   [a  b  0  c]     column-major: a,d,0,g, b,e,0,h, 0,0,1,0, c,f,0,1
    //   [d  e  0  f]
    //   [0  0  1  0]
    //   [g  h  0  1]
    return [
      a, d, 0, g,
      b, e, 0, h,
      0, 0, 1, 0,
      c, f, 0, 1,
    ];
  }

  function updateOverlayTransform() {
    if (!overlayImg || !state.image || !mapContainer) return;

    const imgW = Math.min(state.image.naturalWidth, MAX_IMAGE_DIMENSION);
    const imgH = Math.min(state.image.naturalHeight, MAX_IMAGE_DIMENSION);

    // Corner positions in screen pixels
    let tl, tr, bl, br;

    if (state.isLocked && state.geoCorners) {
      const tlS = latLngToScreen(state.geoCorners.topLeft);
      const trS = latLngToScreen(state.geoCorners.topRight);
      const blS = latLngToScreen(state.geoCorners.bottomLeft);
      const brS = latLngToScreen(state.geoCorners.bottomRight);
      if (!tlS || !trS || !blS || !brS) return;
      tl = tlS; tr = trS; bl = blS; br = brS;
    } else {
      tl = state.corners.topLeft;
      tr = state.corners.topRight;
      bl = state.corners.bottomLeft;
      br = state.corners.bottomRight;
    }

    // Skip degenerate quads where all corners are within ~5px of each other
    const cx = (tl.x + tr.x + bl.x + br.x) / 4;
    const cy = (tl.y + tr.y + bl.y + br.y) / 4;
    const allClose = [tl, tr, bl, br].every(
      p => Math.abs(p.x - cx) < 5 && Math.abs(p.y - cy) < 5
    );
    if (allClose) return;

    // Compute homography from image rect (0,0)-(imgW,imgH) to screen quad
    const matrix = computeHomography(imgW, imgH, tl, tr, br, bl);
    if (!matrix) return;

    overlayImg.style.width = imgW + 'px';
    overlayImg.style.height = imgH + 'px';
    overlayImg.style.opacity = state.opacity;
    overlayImg.style.transform = `matrix3d(${matrix.join(',')})`;

    // Update handle positions
    const cornerPositions = { topLeft: tl, topRight: tr, bottomLeft: bl, bottomRight: br };
    handles.forEach(handle => {
      const key = handle.dataset.corner;
      const pos = cornerPositions[key];
      handle.style.left = pos.x + 'px';
      handle.style.top = pos.y + 'px';
      handle.style.display = state.isLocked ? 'none' : 'block';
    });
  }

  // ── Corner Handle Drag ──
  function setupHandleDrag(handle, cornerKey) {
    let dragging = false;

    handle.addEventListener('pointerdown', (e) => {
      if (state.isLocked) return;
      dragging = true;
      handle.setPointerCapture(e.pointerId);
      if (mapInstance && typeof mapInstance.setOptions === 'function') {
        mapInstance.setOptions({ draggable: false });
      }
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

      // Clamp to container bounds
      state.corners[cornerKey] = {
        x: Math.max(0, Math.min(rect.width, x)),
        y: Math.max(0, Math.min(rect.height, y)),
      };

      updateOverlayTransform();
    });

    const restoreMapDrag = () => {
      if (mapInstance && typeof mapInstance.setOptions === 'function') {
        mapInstance.setOptions({ draggable: true });
      }
    };

    handle.addEventListener('pointerup', (e) => {
      if (dragging) {
        dragging = false;
        handle.releasePointerCapture(e.pointerId);
        restoreMapDrag();
      }
    });

    handle.addEventListener('lostpointercapture', () => {
      dragging = false;
      restoreMapDrag();
    });
  }

  // ── Lock / Unlock ──
  function lockOverlay() {
    if (!state.image || !mapContainer) return;

    const vp = getViewport();
    if (!vp) {
      console.warn('[MapOverlay] Cannot lock: no viewport info in URL');
      alert('Cannot lock: unable to read map viewport from URL. Try panning the map first.');
      return;
    }

    const geoCorners = {};
    for (const key of ['topLeft', 'topRight', 'bottomLeft', 'bottomRight']) {
      const latLng = screenToLatLng(state.corners[key].x, state.corners[key].y);
      if (!latLng) {
        console.warn('[MapOverlay] Cannot lock: projection failed for', key);
        return;
      }
      geoCorners[key] = { lat: latLng.lat, lng: latLng.lng };
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
    if (state.geoCorners) {
      for (const key of ['topLeft', 'topRight', 'bottomLeft', 'bottomRight']) {
        const screen = latLngToScreen(state.geoCorners[key]);
        if (screen) {
          state.corners[key] = { x: screen.x, y: screen.y };
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
  // Google Maps web app doesn't expose JS API events.
  // We detect viewport changes via URL polling + MutationObserver on the DOM.
  let mapChangeCleanup = null;
  let rafId = null;
  let lastViewportUrl = '';

  function onMapChange() {
    if (rafId) cancelAnimationFrame(rafId);
    rafId = requestAnimationFrame(updateOverlayTransform);
  }

  function startMapChangeListener() {
    stopMapChangeListener();
    const cleanups = [];

    // 1. Poll URL for viewport changes (Google Maps updates URL on pan/zoom)
    lastViewportUrl = window.location.href;
    const urlPoll = setInterval(() => {
      const current = window.location.href;
      if (current !== lastViewportUrl) {
        lastViewportUrl = current;
        onMapChange();
      }
    }, 100);
    cleanups.push(() => clearInterval(urlPoll));

    // 2. MutationObserver on map container for real-time DOM changes during drag
    if (mapContainer) {
      let mutationPending = false;
      const observer = new MutationObserver(() => {
        if (mutationPending) return;
        mutationPending = true;
        setTimeout(() => {
          mutationPending = false;
          onMapChange();
        }, 16);
      });
      observer.observe(mapContainer, {
        attributes: true,
        attributeFilter: ['style', 'class'],
        childList: true,
        subtree: true,
      });
      cleanups.push(() => observer.disconnect());
    }

    // 3. Listen for popstate (back/forward navigation)
    const popHandler = () => onMapChange();
    window.addEventListener('popstate', popHandler);
    cleanups.push(() => window.removeEventListener('popstate', popHandler));

    // 4. Use google.maps events if API instance is available
    if (mapInstance && typeof mapInstance.addListener === 'function') {
      const l1 = mapInstance.addListener('bounds_changed', onMapChange);
      const l2 = mapInstance.addListener('zoom_changed', onMapChange);
      cleanups.push(() => { l1.remove(); l2.remove(); });
    }

    mapChangeCleanup = () => cleanups.forEach(fn => fn());
  }

  function stopMapChangeListener() {
    if (mapChangeCleanup) { mapChangeCleanup(); mapChangeCleanup = null; }
    if (rafId) { cancelAnimationFrame(rafId); rafId = null; }
  }

  // ── Persistence ──
  function saveOverlay() {
    if (!state.isLocked || !state.geoCorners || !state.imageDataUrl) return;

    const name = prompt('Name this overlay:', 'Overlay ' + (state.savedOverlays.length + 1));
    if (!name) return;

    // geoCorners are already plain {lat, lng} objects
    const serializedCorners = JSON.parse(JSON.stringify(state.geoCorners));

    const entry = {
      id: crypto.randomUUID(),
      name: name,
      imageDataUrl: state.imageDataUrl,
      corners: serializedCorners,
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

      // Reconstruct geoCorners as plain {lat, lng} objects
      state.geoCorners = {};
      for (const key of ['topLeft', 'topRight', 'bottomLeft', 'bottomRight']) {
        state.geoCorners[key] = { lat: entry.corners[key].lat, lng: entry.corners[key].lng };
      }
      state.isLocked = true;

      createOverlayElement();
      updateToolbarState();
      startMapChangeListener();

      // Update opacity slider
      const slider = document.getElementById('mo-opacity');
      if (slider) slider.value = Math.round(state.opacity * 100);

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
      // Rollback the last added entry on quota exhaustion
      state.savedOverlays.pop();
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
    list.replaceChildren();
    if (state.savedOverlays.length === 0) {
      const empty = document.createElement('p');
      empty.style.cssText = 'color:#9aa0a6;padding:8px 0;';
      empty.textContent = 'No saved overlays';
      list.appendChild(empty);
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
      deleteBtn.textContent = '\u2715';
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
      if (file.size > MAX_FILE_SIZE) {
        alert('File is too large (max 20 MB).');
        fileInput.value = '';
        return;
      }
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

  // ── Navigation Re-discovery ──
  function startNavigationWatcher() {
    let lastUrl = window.location.href;
    const checkUrl = () => {
      if (window.location.href !== lastUrl) {
        lastUrl = window.location.href;
        findMapInstance();
      }
    };
    window.addEventListener('popstate', checkUrl);
    setInterval(checkUrl, 2000);
  }

  // ── Initialization ──
  function init() {
    loadPersistedOverlays();
    createToolbar();
    wireEvents();
    updateToolbarState();

    startNavigationWatcher();

    // Try to find the map instance with retries (Google Maps loads async)
    let attempts = 0;
    const maxAttempts = 30;
    const retryInterval = setInterval(() => {
      attempts++;
      if (!mapContainer) {
        mapContainer = findMapContainer();
      }
      if (findMapInstance()) {
        console.log('[MapOverlay] Map instance found after', attempts, 'attempt(s)');
        clearInterval(retryInterval);
      } else if (attempts >= maxAttempts) {
        console.warn('[MapOverlay] Map instance not found after', maxAttempts, 'attempts. Overlay will work without geo-locking.');
        if (!mapContainer) {
          mapContainer = findMapContainer() || document.body;
        }
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
})();
