import SwiftUI

struct ControlPanelView: View {
    @ObservedObject var viewModel: MapOverlayViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Opacity slider
            if viewModel.selectedImage != nil {
                HStack {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundColor(.secondary)
                    Slider(value: $viewModel.opacity, in: 0.05...1.0)
                    Text("\(Int(viewModel.opacity * 100))%")
                        .font(.caption)
                        .frame(width: 36)
                }
                .padding(.horizontal)
            }

            // Action buttons
            HStack(spacing: 16) {
                Button {
                    viewModel.showingImagePicker = true
                } label: {
                    Label("Import", systemImage: "photo.on.rectangle")
                        .font(.callout)
                }
                .disabled(viewModel.isLocked)

                Button {
                    viewModel.showingSavedOverlays = true
                } label: {
                    Label("Saved", systemImage: "bookmark")
                        .font(.callout)
                }

                Spacer()

                if viewModel.selectedImage != nil {
                    if viewModel.isLocked {
                        Button {
                            viewModel.unlockOverlay()
                        } label: {
                            Label("Unlock", systemImage: "lock.open")
                                .font(.callout)
                        }

                        Button {
                            viewModel.showingSaveDialog = true
                        } label: {
                            Label("Save", systemImage: "square.and.arrow.down")
                                .font(.callout)
                        }
                    } else {
                        Button {
                            // Lock will be triggered from ContentView
                            // which has access to the map's visible region
                            NotificationCenter.default.post(
                                name: .lockOverlayRequested,
                                object: nil
                            )
                        } label: {
                            Label("Lock", systemImage: "lock")
                                .font(.callout)
                        }
                    }

                    Button(role: .destructive) {
                        viewModel.removeOverlay()
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(.callout)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

extension Notification.Name {
    static let lockOverlayRequested = Notification.Name("lockOverlayRequested")
}
