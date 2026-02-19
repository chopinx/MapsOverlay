import SwiftUI
import GoogleMaps
import CoreLocation

struct ContentView: View {
    @StateObject private var viewModel = MapOverlayViewModel()
    @StateObject private var authService = GoogleAuthService()
    @State private var currentVisibleRegion: GMSVisibleRegion?
    @State private var saveOverlayName = ""
    @State private var showingSettings = false
    @State private var showingSearch = false
    @State private var showingPins = false
    @State private var mapViewID = UUID()
    @State private var animateTarget: CLLocationCoordinate2D?

    var body: some View {
        Group {
            if Config.hasAPIKey {
                mapView
                    .id(mapViewID)
            } else {
                setupPrompt
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(authService: authService)
        }
        .onReceive(NotificationCenter.default.publisher(for: .apiKeyChanged)) { _ in
            mapViewID = UUID()
        }
    }

    private var setupPrompt: some View {
        VStack(spacing: 24) {
            Image(systemName: "map.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue.gradient)
            Text("Welcome to MapsOverlay")
                .font(.title2.bold())
            Text("Add your Google Maps API key to get started.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingSettings = true
            } label: {
                Label("Open Settings", systemImage: "gearshape")
                    .font(.body.bold())
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
    }

    private var mapView: some View {
        ZStack {
            GoogleMapView(
                viewModel: viewModel,
                onVisibleRegionChanged: { region in
                    currentVisibleRegion = region
                },
                animateToCoordinate: animateTarget
            )
            .ignoresSafeArea()

            if let image = viewModel.selectedImage, !viewModel.isLocked {
                OverlayImageView(image: image, opacity: viewModel.opacity, rotation: viewModel.rotation)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Control panel (collapses when locked)
            VStack {
                Spacer()
                ControlPanelView(viewModel: viewModel)
            }
        }
        .overlay(alignment: .topLeading) {
            topBar
        }
        .sheet(isPresented: $showingSearch) {
            PlaceSearchView { coordinate, name in
                viewModel.addPin(name: name, coordinate: coordinate)
                animateTarget = coordinate
            }
        }
        .sheet(isPresented: $showingPins) {
            SavedPinsView(viewModel: viewModel) { pin in
                animateTarget = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
            }
        }
        .sheet(isPresented: $viewModel.showingImagePicker) {
            ImagePicker(selectedImage: $viewModel.selectedImage)
        }
        .sheet(isPresented: $viewModel.showingSavedOverlays) {
            SavedOverlaysView(viewModel: viewModel)
        }
        .alert("Save Overlay", isPresented: $viewModel.showingSaveDialog) {
            TextField("Overlay name", text: $saveOverlayName)
            Button("Save") {
                viewModel.saveOverlay(name: saveOverlayName.isEmpty ? "Untitled" : saveOverlayName)
                saveOverlayName = ""
            }
            Button("Cancel", role: .cancel) {
                saveOverlayName = ""
            }
        } message: {
            Text("Give this overlay a name to find it later.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .lockOverlayRequested)) { _ in
            if let region = currentVisibleRegion {
                viewModel.lockOverlay(visibleRegion: region)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            circleButton(icon: "magnifyingglass", accessibilityLabel: "Search places") {
                showingSearch = true
            }
            circleButton(icon: "mappin.and.ellipse", accessibilityLabel: "Saved pins") {
                showingPins = true
            }
            circleButton(icon: "gearshape", accessibilityLabel: "Settings") {
                showingSettings = true
            }
            SignInView(authService: authService)
        }
        .padding(.leading, 16)
        .padding(.top, 12)
    }

    private func circleButton(
        icon: String,
        accessibilityLabel: String = "",
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}
