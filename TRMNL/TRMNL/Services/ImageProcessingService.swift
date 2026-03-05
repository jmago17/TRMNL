import UIKit

actor ImageProcessingService {
    static let displayWidth = 800
    static let displayHeight = 480

    func processForDisplay(_ image: UIImage) -> UIImage {
        resize(image)
    }

    func jpegData(from image: UIImage, quality: CGFloat = 0.85) -> Data? {
        image.jpegData(compressionQuality: quality)
    }

    private func resize(_ image: UIImage) -> UIImage {
        let targetSize = CGSize(
            width: Self.displayWidth,
            height: Self.displayHeight
        )

        let widthRatio = targetSize.width / image.size.width
        let heightRatio = targetSize.height / image.size.height
        let ratio = min(widthRatio, heightRatio)

        let scaledSize = CGSize(
            width: image.size.width * ratio,
            height: image.size.height * ratio
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            let origin = CGPoint(
                x: (targetSize.width - scaledSize.width) / 2,
                y: (targetSize.height - scaledSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }


}

enum ImageProcessingError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process the selected image."
        }
    }
}
