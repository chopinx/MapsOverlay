import SwiftUI

struct OverlayImageView: View {
    let image: UIImage
    let opacity: Double

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}
