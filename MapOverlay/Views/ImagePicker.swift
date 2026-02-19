import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    private static let maxDimension: CGFloat = 4096

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self)
            else { return }

            provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                guard let self, let picked = image as? UIImage else { return }
                let final = Self.downscaleIfNeeded(picked, maxDimension: ImagePicker.maxDimension)
                DispatchQueue.main.async {
                    self.parent.selectedImage = final
                }
            }
        }

        private static func downscaleIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
            let width = image.size.width
            let height = image.size.height
            guard width > maxDimension || height > maxDimension else { return image }

            let scale = min(maxDimension / width, maxDimension / height)
            let newSize = CGSize(width: width * scale, height: height * scale)

            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
    }
}
