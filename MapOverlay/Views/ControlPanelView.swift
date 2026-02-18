import SwiftUI

struct ControlPanelView: View {
    @ObservedObject var viewModel: MapOverlayViewModel
    @State private var showLockedControls = false
    @State private var hideAlignmentPanel = false

    var body: some View {
        if viewModel.isLocked {
            lockedView
        } else if viewModel.selectedImage != nil {
            alignmentView
        } else {
            idleView
        }
    }

    // MARK: - Idle (no image loaded)

    private var idleView: some View {
        HStack(spacing: 10) {
            actionButton("Import", icon: "photo.on.rectangle") {
                viewModel.showingImagePicker = true
            }
            actionButton("Saved", icon: "bookmark") {
                viewModel.showingSavedOverlays = true
            }
        }
        .padding(.bottom, 24)
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Alignment mode

    private var alignmentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !hideAlignmentPanel {
                VStack(spacing: 12) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)

                    // Opacity slider
                    HStack(spacing: 10) {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Slider(value: $viewModel.opacity, in: 0.05...1.0)
                            .tint(.blue)
                        Text("\(Int(viewModel.opacity * 100))%")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)

                    // Action buttons
                    HStack(spacing: 10) {
                        actionButton("Import", icon: "photo.on.rectangle") {
                            viewModel.showingImagePicker = true
                        }
                        actionButton("Saved", icon: "bookmark") {
                            viewModel.showingSavedOverlays = true
                        }

                        Spacer()

                        actionButton("Lock", icon: "lock.fill", tint: .green) {
                            NotificationCenter.default.post(
                                name: .lockOverlayRequested,
                                object: nil
                            )
                        }
                        actionButton("Remove", icon: "trash", tint: .red) {
                            viewModel.removeOverlay()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 8)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Hide/show toggle
            Button {
                withAnimation(.spring(response: 0.3)) {
                    hideAlignmentPanel.toggle()
                }
            } label: {
                Image(systemName: hideAlignmentPanel ? "slider.horizontal.3" : "chevron.down")
                    .font(.body.bold())
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.6), in: Circle())
            }
            .padding(.leading, 16)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Locked mode

    private var lockedView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showLockedControls {
                VStack(alignment: .leading, spacing: 10) {
                    // Opacity slider
                    HStack(spacing: 8) {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                        Slider(value: $viewModel.opacity, in: 0.05...1.0)
                            .tint(.white)
                            .frame(width: 120)
                        Text("\(Int(viewModel.opacity * 100))%")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.6), in: Capsule())

                    // Action buttons with labels
                    HStack(spacing: 8) {
                        labeledButton("Unlock", icon: "lock.open.fill", tint: .orange) {
                            withAnimation { showLockedControls = false }
                            viewModel.unlockOverlay()
                        }
                        labeledButton("Save", icon: "square.and.arrow.down", tint: .cyan) {
                            viewModel.showingSaveDialog = true
                        }
                        labeledButton("Remove", icon: "trash", tint: .red) {
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

    /// Pill button used in idle and alignment modes
    private func actionButton(
        _ title: String,
        icon: String,
        tint: Color = .blue,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(tint.opacity(0.15), in: Capsule())
                .foregroundStyle(tint)
        }
    }

    /// Labeled circle button used in locked mode
    private func labeledButton(
        _ title: String,
        icon: String,
        tint: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.6), in: Circle())
                Text(title)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(tint)
        }
    }
}

extension Notification.Name {
    static let lockOverlayRequested = Notification.Name("lockOverlayRequested")
}
