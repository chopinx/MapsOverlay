import SwiftUI

struct OverlayImageView: View {
    let image: UIImage
    let opacity: Double
    let rotation: Double

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}
