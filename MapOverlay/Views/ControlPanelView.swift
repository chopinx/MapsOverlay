import SwiftUI

struct ControlPanelView: View {
    @ObservedObject var viewModel: MapOverlayViewModel
    @State private var showLockedControls = false

    var body: some View {
        if viewModel.isLocked {
            lockedView
        } else if viewModel.selectedImage != nil {
            alignmentView
        } else {
            idleView
        }
    }

    // MARK: - Idle (no image loaded): minimal floating buttons

    private var idleView: some View {
        HStack(spacing: 12) {
            pillButton("Import", icon: "photo.on.rectangle") {
                viewModel.showingImagePicker = true
            }
            pillButton("Saved", icon: "bookmark") {
                viewModel.showingSavedOverlays = true
            }
        }
        .padding(.bottom, 24)
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Alignment mode: full panel for adjustments

    private var alignmentView: some View {
        VStack(spacing: 10) {
            // Drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            // Opacity slider
            HStack(spacing: 8) {
                Image(systemName: "sun.min")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $viewModel.opacity, in: 0.05...1.0)
                    .tint(.blue)
                Image(systemName: "sun.max.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(Int(viewModel.opacity * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 36)
            }
            .padding(.horizontal, 16)

            // Action buttons
            HStack(spacing: 12) {
                pillButton("Import", icon: "photo.on.rectangle") {
                    viewModel.showingImagePicker = true
                }
                pillButton("Saved", icon: "bookmark") {
                    viewModel.showingSavedOverlays = true
                }

                Spacer()

                pillButton("Lock", icon: "lock.fill", tint: .green) {
                    NotificationCenter.default.post(
                        name: .lockOverlayRequested,
                        object: nil
                    )
                }
                pillButton("Remove", icon: "trash", tint: .red) {
                    viewModel.removeOverlay()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Locked: compact floating controls (bottom-left)

    private var lockedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showLockedControls {
                VStack(spacing: 8) {
                    // Opacity slider (compact)
                    HStack(spacing: 6) {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        Slider(value: $viewModel.opacity, in: 0.05...1.0)
                            .tint(.white)
                            .frame(width: 100)
                        Text("\(Int(viewModel.opacity * 100))%")
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.6), in: Capsule())

                    HStack(spacing: 8) {
                        compactButton("Unlock", icon: "lock.open.fill", tint: .orange) {
                            withAnimation { showLockedControls = false }
                            viewModel.unlockOverlay()
                        }
                        compactButton("Save", icon: "square.and.arrow.down", tint: .blue) {
                            viewModel.showingSaveDialog = true
                        }
                        compactButton("Remove", icon: "trash", tint: .red) {
                            withAnimation { showLockedControls = false }
                            viewModel.removeOverlay()
                        }
                    }
                }
                .transition(.scale(scale: 0.8, anchor: .bottomLeading).combined(with: .opacity))
            }

            // Toggle button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showLockedControls.toggle()
                }
            } label: {
                Image(systemName: showLockedControls ? "xmark" : "ellipsis")
                    .font(.body.bold())
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.6), in: Circle())
            }
        }
        .padding(.bottom, 24)
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Button styles

    private func pillButton(
        _ title: String,
        icon: String,
        tint: Color = .blue,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(tint.opacity(0.15), in: Capsule())
                .foregroundColor(tint)
        }
    }

    private func compactButton(
        _ title: String,
        icon: String,
        tint: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundColor(tint)
                .frame(width: 40, height: 40)
                .background(.black.opacity(0.6), in: Circle())
        }
    }
}

extension Notification.Name {
    static let lockOverlayRequested = Notification.Name("lockOverlayRequested")
}
