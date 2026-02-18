import SwiftUI
import GoogleMaps

struct ContentView: View {
    @StateObject private var viewModel = MapOverlayViewModel()
    @StateObject private var authService = GoogleAuthService()
    @State private var currentVisibleRegion: GMSVisibleRegion?
    @State private var saveOverlayName = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            // Google Map layer
            GoogleMapView(
                viewModel: viewModel,
                onVisibleRegionChanged: { region in
                    currentVisibleRegion = region
                }
            )
            .ignoresSafeArea(edges: .top)

            // Floating overlay image (visible during alignment, before lock)
            if let image = viewModel.selectedImage, !viewModel.isLocked {
                OverlayImageView(image: image, opacity: viewModel.opacity)
                    .ignoresSafeArea(edges: .top)
            }

            // Controls at bottom
            VStack(spacing: 0) {
                Spacer()
                ControlPanelView(viewModel: viewModel)
            }
        }
        .overlay(alignment: .topTrailing) {
            // Sign-in button in top-right
            SignInView(authService: authService)
                .padding(.trailing, 12)
                .padding(.top, 8)
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
