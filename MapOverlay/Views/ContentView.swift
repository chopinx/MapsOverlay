import SwiftUI
import GoogleMaps
import CoreLocation

private enum Layout {
    static let floatingControlInset: CGFloat = 8
    static let edgePadding: CGFloat = 16
    static let buttonSpacing: CGFloat = 10
    static let buttonSize: CGFloat = 44
    static let shadowOpacity: CGFloat = 0.1
    static let shadowRadius: CGFloat = 4
    static let shadowOffsetY: CGFloat = 2
}

struct ContentView: View {
    @StateObject private var viewModel = MapOverlayViewModel()
    @StateObject private var authService = GoogleAuthService()
    @State private var saveOverlayName = ""
    @State private var showingSettings = false
    @State private var showingSearch = false
    @State private var showingPins = false
    @State private var mapViewID = UUID()
    @State private var lastKnownAPIKey = Config.googleMapsAPIKey

    var body: some View {
        Group {
            if Config.hasAPIKey {
                mapView
                    .id(mapViewID)
            } else {
                setupPrompt
            }
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            let currentKey = Config.googleMapsAPIKey
            if currentKey != lastKnownAPIKey {
                lastKnownAPIKey = currentKey
                mapViewID = UUID()
            }
        }) {
            SettingsView(authService: authService)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
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
        GeometryReader { geo in
            ZStack {
                GoogleMapView(
                    viewModel: viewModel,
                    onVisibleRegionChanged: { region in
                        viewModel.currentVisibleRegion = region
                    },
                    animateToCoordinate: viewModel.animateTarget
                )
                .ignoresSafeArea()

                if let image = viewModel.selectedImage, !viewModel.isLocked {
                    GeometryReader { geometry in
                        if viewModel.isTransformMode || !viewModel.transformCorners.isIdentity {
                            FreeTransformOverlayView(viewModel: viewModel, viewSize: geometry.size)
                        } else {
                            OverlayImageView(image: image, opacity: viewModel.opacity, rotation: viewModel.rotation)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .allowsHitTesting(false)
                        }
                    }
                    .ignoresSafeArea()
                }

                VStack {
                    topBar
                        .padding(.top, geo.safeAreaInsets.top + Layout.floatingControlInset)

                    Spacer()

                    ControlPanelView(viewModel: viewModel)
                        .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? geo.safeAreaInsets.bottom : Layout.floatingControlInset)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingSearch) {
            PlaceSearchView { coordinate, name, query in
                viewModel.addPin(name: name, coordinate: coordinate)
                viewModel.fetchBoundary(for: query)
                viewModel.animateTarget = coordinate
            }
        }
        .sheet(isPresented: $showingPins) {
            SavedPinsView(viewModel: viewModel) { pin in
                viewModel.currentBoundary = nil
                viewModel.animateTarget = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
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
    }

    private var topBar: some View {
        HStack(spacing: Layout.buttonSpacing) {
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
        .padding(.leading, Layout.edgePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .frame(width: Layout.buttonSize, height: Layout.buttonSize)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(Layout.shadowOpacity), radius: Layout.shadowRadius, y: Layout.shadowOffsetY)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}
