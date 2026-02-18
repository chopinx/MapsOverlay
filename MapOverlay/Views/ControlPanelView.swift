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

    // MARK: - Idle

    private var idleView: some View {
        HStack(spacing: 10) {
            circleIcon("photo.on.rectangle") { viewModel.showingImagePicker = true }
            circleIcon("bookmark") { viewModel.showingSavedOverlays = true }
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
                    sliderRow("rotate.right", value: $viewModel.rotation, range: -180...180, step: 1, tint: .orange)

                    HStack(spacing: 10) {
                        circleIcon("lock.fill", tint: .green) {
                            NotificationCenter.default.post(name: .lockOverlayRequested, object: nil)
                        }
                        circleIcon("trash", tint: .red) { viewModel.removeOverlay() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 8)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            toggleButton(icon: hideAlignmentPanel ? "slider.horizontal.3" : "chevron.down") {
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
                    darkSliderRow("circle.lefthalf.filled", value: $viewModel.opacity, range: 0.05...1.0, tint: .white)
                    darkSliderRow("rotate.right", value: $viewModel.rotation, range: -180...180, step: 1, tint: .orange)

                    HStack(spacing: 8) {
                        darkCircleIcon("lock.open.fill", tint: .orange) {
                            withAnimation { showLockedControls = false }
                            viewModel.unlockOverlay()
                        }
                        darkCircleIcon("square.and.arrow.down", tint: .cyan) {
                            viewModel.showingSaveDialog = true
                        }
                        darkCircleIcon("trash", tint: .red) {
                            withAnimation { showLockedControls = false }
                            viewModel.removeOverlay()
                        }
                    }
                }
                .transition(.scale(scale: 0.8, anchor: .bottomLeading).combined(with: .opacity))
            }

            toggleButton(icon: showLockedControls ? "xmark" : "ellipsis") {
                showLockedControls.toggle()
            }
        }
        .padding(.bottom, 24)
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Components

    private func circleIcon(_ icon: String, tint: Color = .blue, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body)
                .padding(10)
                .background(tint.opacity(0.15), in: Circle())
                .foregroundStyle(tint)
        }
    }

    private func darkCircleIcon(_ icon: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(.black.opacity(0.6), in: Circle())
        }
    }

    private func toggleButton(icon: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { action() }
        } label: {
            Image(systemName: icon)
                .font(.body.bold())
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.6), in: Circle())
        }
    }

    private func sliderRow(_ icon: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double = 0, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if step > 0 {
                Slider(value: value, in: range, step: step).tint(tint)
            } else {
                Slider(value: value, in: range).tint(tint)
            }
        }
        .padding(.horizontal, 16)
    }

    private func darkSliderRow(_ icon: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double = 0, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            if step > 0 {
                Slider(value: value, in: range, step: step).tint(tint).frame(width: 140)
            } else {
                Slider(value: value, in: range).tint(tint).frame(width: 140)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.6), in: Capsule())
    }
}

extension Notification.Name {
    static let lockOverlayRequested = Notification.Name("lockOverlayRequested")
}
