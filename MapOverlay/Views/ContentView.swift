import SwiftUI
import GoogleMaps

struct ContentView: View {
    @StateObject private var viewModel = MapOverlayViewModel()
    @StateObject private var authService = GoogleAuthService()
    @State private var currentVisibleRegion: GMSVisibleRegion?
    @State private var saveOverlayName = ""
    @State private var showingSettings = false
    @State private var showingSearch = false
    @State private var mapViewID = UUID()
    @State private var searchTarget: CLLocationCoordinate2D?

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
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("Welcome to MapOverlay")
                .font(.title2.bold())
            Text("Add your Google Maps API key to get started.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                showingSettings = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var mapView: some View {
        ZStack(alignment: .bottom) {
            GoogleMapView(
                viewModel: viewModel,
                onVisibleRegionChanged: { region in
                    currentVisibleRegion = region
                },
                targetCoordinate: searchTarget
            )
            .ignoresSafeArea(edges: .top)

            if let image = viewModel.selectedImage, !viewModel.isLocked {
                OverlayImageView(image: image, opacity: viewModel.opacity)
                    .ignoresSafeArea(edges: .top)
            }

            VStack(spacing: 0) {
                Spacer()
                ControlPanelView(viewModel: viewModel)
            }
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                Button { showingSearch = true } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                SignInView(authService: authService)
            }
            .padding(.trailing, 12)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showingSearch) {
            PlaceSearchView { coordinate, _ in
                searchTarget = coordinate
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
}
