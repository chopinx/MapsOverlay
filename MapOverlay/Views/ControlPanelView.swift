import SwiftUI
import Foundation

struct ControlPanelView: View {
    @ObservedObject var viewModel: MapOverlayViewModel
    @State private var showLockedControls = false
    @State private var hideAlignmentPanel = false
    @State private var showRemoveConfirmation = false

    var body: some View {
        Group {
            if viewModel.isLocked {
                lockedView
            } else if viewModel.selectedImage != nil {
                alignmentView
            } else {
                idleView
            }
        }
        .animation(.spring(response: 0.3), value: viewModel.isLocked)
        .confirmationDialog("Remove Overlay?", isPresented: $showRemoveConfirmation, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                withAnimation { showLockedControls = false }
                viewModel.removeOverlay()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the current overlay from the map.")
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        HStack(spacing: 10) {
            circleIcon("photo.on.rectangle", accessibilityLabel: "Import image") { viewModel.showingImagePicker = true }
            circleIcon("bookmark", accessibilityLabel: "Saved overlays") { viewModel.showingSavedOverlays = true }
        }
        .padding(.bottom, 24)
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Alignment

    private var alignmentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !hideAlignmentPanel {
                VStack(spacing: 12) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)

                    sliderRow("circle.lefthalf.filled", value: $viewModel.opacity, range: 0.05...1.0, tint: .blue)
                        .accessibilityLabel("Opacity")
                    sliderRow("rotate.right", value: $viewModel.rotation, range: -180...180, step: 1, tint: .orange)
                        .accessibilityLabel("Rotation")

                    if viewModel.isTransformMode && !viewModel.transformCorners.isIdentity {
                        Button { viewModel.resetTransform() } label: {
                            Text("Reset Transform")
                                .font(.caption.bold())
                                .foregroundColor(.purple)
                        }
                        .padding(.horizontal, 16)
                    }

                    HStack(spacing: 10) {
                        circleIcon(
                            "skew",
                            tint: viewModel.isTransformMode ? .purple : .blue,
                            accessibilityLabel: viewModel.isTransformMode ? "Exit transform" : "Free transform"
                        ) {
                            viewModel.toggleTransformMode()
                        }
                        .overlay(
                            viewModel.isTransformMode
                                ? Circle().stroke(Color.purple, lineWidth: 2).frame(width: 48, height: 48)
                                : nil
                        )
                        circleIcon("lock.fill", tint: .green, accessibilityLabel: "Lock overlay") {
                            viewModel.lockOverlay()
                        }
                        circleIcon("trash", tint: .red, accessibilityLabel: "Remove overlay") {
                            showRemoveConfirmation = true
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

            toggleButton(icon: hideAlignmentPanel ? "slider.horizontal.3" : "chevron.down", accessibilityLabel: hideAlignmentPanel ? "Show controls" : "Hide controls") {
                hideAlignmentPanel.toggle()
            }
            .padding(.leading, 16)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Locked

    private var lockedView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showLockedControls {
                VStack(alignment: .leading, spacing: 10) {
                    sliderRow("circle.lefthalf.filled", value: $viewModel.opacity, range: 0.05...1.0, tint: .white, isDark: true)
                        .accessibilityLabel("Opacity")
                    sliderRow("rotate.right", value: $viewModel.rotation, range: -180...180, step: 1, tint: .orange, isDark: true)
                        .accessibilityLabel("Rotation")

                    HStack(spacing: 8) {
                        circleIcon("lock.open.fill", tint: .orange, isDark: true, accessibilityLabel: "Unlock overlay") {
                            withAnimation { showLockedControls = false }
                            viewModel.unlockOverlay()
                        }
                        circleIcon("square.and.arrow.down", tint: .cyan, isDark: true, accessibilityLabel: "Save overlay") {
                            viewModel.showingSaveDialog = true
                        }
                        circleIcon("trash", tint: .red, isDark: true, accessibilityLabel: "Remove overlay") {
                            showRemoveConfirmation = true
                        }
                    }
                }
                .transition(.scale(scale: 0.8, anchor: .bottomLeading).combined(with: .opacity))
            }

            toggleButton(icon: showLockedControls ? "xmark" : "ellipsis", accessibilityLabel: "Toggle controls") {
                showLockedControls.toggle()
            }
        }
        .padding(.bottom, 24)
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Components

    private func circleIcon(_ icon: String, tint: Color = .blue, isDark: Bool = false, accessibilityLabel: String = "", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(
                    isDark ? AnyShapeStyle(.black.opacity(0.6)) : AnyShapeStyle(tint.opacity(0.15)),
                    in: Circle()
                )
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private func toggleButton(icon: String, accessibilityLabel: String = "", action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { action() }
        } label: {
            Image(systemName: icon)
                .font(.body.bold())
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.6), in: Circle())
        }
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func sliderRow(_ icon: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double = 0, tint: Color, isDark: Bool = false) -> some View {
        let slider = Group {
            if step > 0 {
                Slider(value: value, in: range, step: step).tint(tint)
            } else {
                Slider(value: value, in: range).tint(tint)
            }
        }

        if isDark {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                slider.frame(width: 140)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.black.opacity(0.6), in: Capsule())
        } else {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                slider
            }
            .padding(.horizontal, 16)
        }
    }
}
