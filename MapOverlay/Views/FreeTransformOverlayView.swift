import SwiftUI

struct FreeTransformOverlayView: View {
    @ObservedObject var viewModel: MapOverlayViewModel
    let viewSize: CGSize

    private let transformService = FreeTransformService()
    private let handleSize: CGFloat = 28
    private let hitTargetSize: CGFloat = 44

    var body: some View {
        ZStack {
            transformedImage
            if viewModel.isTransformMode {
                handleLayer
            }
        }
    }

    // MARK: - Transformed Image

    @ViewBuilder
    private var transformedImage: some View {
        if let image = viewModel.selectedImage {
            let projection = transformService.projectionTransform(
                for: viewModel.transformCorners,
                in: viewSize
            )
            Image(uiImage: image)
                .resizable()
                .frame(width: viewSize.width, height: viewSize.height)
                .modifier(FreeTransformEffect(transform: projection))
                .rotationEffect(.degrees(viewModel.rotation))
                .opacity(viewModel.opacity)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Corner Handles

    private var handleLayer: some View {
        ZStack {
            cornerHandle(keyPath: \.topLeft)
            cornerHandle(keyPath: \.topRight)
            cornerHandle(keyPath: \.bottomLeft)
            cornerHandle(keyPath: \.bottomRight)
        }
    }

    private func cornerHandle(keyPath: WritableKeyPath<FreeTransformCorners, CGPoint>) -> some View {
        let normalizedPoint = viewModel.transformCorners[keyPath: keyPath]
        let position = denormalizePoint(normalizedPoint)

        return Circle()
            .fill(.white)
            .frame(width: handleSize, height: handleSize)
            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            .frame(width: hitTargetSize, height: hitTargetSize)
            .contentShape(Circle())
            .position(position)
            .gesture(handleDragGesture(for: keyPath))
    }

    private func denormalizePoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * viewSize.width, y: point.y * viewSize.height)
    }

    private func normalizePoint(_ point: CGPoint) -> CGPoint? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }
        return CGPoint(
            x: min(max(point.x / viewSize.width, 0), 1),
            y: min(max(point.y / viewSize.height, 0), 1)
        )
    }

    private func handleDragGesture(for keyPath: WritableKeyPath<FreeTransformCorners, CGPoint>) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let normalized = normalizePoint(value.location) else { return }
                viewModel.transformCorners[keyPath: keyPath] = normalized
            }
    }
}

// MARK: - GeometryEffect

/// Applies a ProjectionTransform without clipping the result to the original frame.
struct FreeTransformEffect: GeometryEffect {
    var transform: ProjectionTransform

    var animatableData: AnimatablePair<
        AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>>,
        AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>>
    > {
        get {
            .init(
                .init(.init(transform.m11, transform.m12), .init(transform.m13, transform.m21)),
                .init(.init(transform.m22, transform.m23), .init(transform.m31, transform.m32))
            )
        }
        set {
            transform.m11 = newValue.first.first.first
            transform.m12 = newValue.first.first.second
            transform.m13 = newValue.first.second.first
            transform.m21 = newValue.first.second.second
            transform.m22 = newValue.second.first.first
            transform.m23 = newValue.second.first.second
            transform.m31 = newValue.second.second.first
            transform.m32 = newValue.second.second.second
        }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        transform
    }
}
