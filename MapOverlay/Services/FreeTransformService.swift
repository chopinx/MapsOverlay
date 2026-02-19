import SwiftUI
import UIKit

struct FreeTransformCorners: Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomLeft: CGPoint
    var bottomRight: CGPoint

    static let identity = FreeTransformCorners(
        topLeft: CGPoint(x: 0, y: 0),
        topRight: CGPoint(x: 1, y: 0),
        bottomLeft: CGPoint(x: 0, y: 1),
        bottomRight: CGPoint(x: 1, y: 1)
    )

    var isIdentity: Bool { self == .identity }
}

final class FreeTransformService {
    private let ciContext: CIContext

    init() {
        if let device = MTLCreateSystemDefaultDevice() {
            ciContext = CIContext(mtlDevice: device)
        } else {
            ciContext = CIContext()
        }
    }

    /// Computes the ProjectionTransform for real-time SwiftUI preview.
    static func projectionTransform(for corners: FreeTransformCorners, in size: CGSize) -> ProjectionTransform {
        let W = size.width
        let H = size.height
        let tl = CGPoint(x: corners.topLeft.x * W, y: corners.topLeft.y * H)
        let tr = CGPoint(x: corners.topRight.x * W, y: corners.topRight.y * H)
        let br = CGPoint(x: corners.bottomRight.x * W, y: corners.bottomRight.y * H)
        let bl = CGPoint(x: corners.bottomLeft.x * W, y: corners.bottomLeft.y * H)

        return homography(sourceSize: size, topLeft: tl, topRight: tr, bottomRight: br, bottomLeft: bl)
    }

    /// Bakes the transform into a UIImage at lock time.
    func bakeTransform(image: UIImage, corners: FreeTransformCorners) -> UIImage? {
        guard !corners.isIdentity else { return image }
        guard let cgImage = image.cgImage else { return nil }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIPerspectiveTransform") else { return nil }

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(toCIVector(corners.topLeft, width: width, height: height), forKey: "inputTopLeft")
        filter.setValue(toCIVector(corners.topRight, width: width, height: height), forKey: "inputTopRight")
        filter.setValue(toCIVector(corners.bottomRight, width: width, height: height), forKey: "inputBottomRight")
        filter.setValue(toCIVector(corners.bottomLeft, width: width, height: height), forKey: "inputBottomLeft")

        guard let output = filter.outputImage else { return nil }
        guard let rendered = ciContext.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: rendered, scale: image.scale, orientation: image.imageOrientation)
    }

    private func toCIVector(_ point: CGPoint, width: CGFloat, height: CGFloat) -> CIVector {
        CIVector(x: point.x * width, y: (1 - point.y) * height)
    }

    // MARK: - Homography

    /// Maps source rect (0,0)-(W,H) to target quad (tl, tr, br, bl).
    ///
    /// Solves: x' = (ax + by + c) / (gx + hy + 1)
    ///         y' = (dx + ey + f) / (gx + hy + 1)
    ///
    /// SwiftUI uses row-vector convention [x y 1] * M, so the matrix is transposed.
    private static func homography(
        sourceSize: CGSize,
        topLeft tl: CGPoint, topRight tr: CGPoint, bottomRight br: CGPoint, bottomLeft bl: CGPoint
    ) -> ProjectionTransform {
        let W = sourceSize.width
        let H = sourceSize.height
        guard W > 0, H > 0 else { return ProjectionTransform(.identity) }

        // Solve for g, h from the 4th-corner constraint
        let sA = W * (tr.x - br.x)
        let sB = H * (bl.x - br.x)
        let sC = br.x - tr.x - bl.x + tl.x
        let sD = W * (tr.y - br.y)
        let sE = H * (bl.y - br.y)
        let sF = br.y - tr.y - bl.y + tl.y

        let det = sA * sE - sB * sD
        guard abs(det) > 1e-10 else { return ProjectionTransform(.identity) }

        let g = (sC * sE - sB * sF) / det
        let h = (sA * sF - sC * sD) / det

        let a = tr.x * g + (tr.x - tl.x) / W
        let b = bl.x * h + (bl.x - tl.x) / H
        let c = tl.x
        let d = tr.y * g + (tr.y - tl.y) / W
        let e = bl.y * h + (bl.y - tl.y) / H
        let f = tl.y

        // Transpose for row-vector convention
        var t = ProjectionTransform()
        t.m11 = a;  t.m12 = d;  t.m13 = g
        t.m21 = b;  t.m22 = e;  t.m23 = h
        t.m31 = c;  t.m32 = f;  t.m33 = 1
        return t
    }
}
