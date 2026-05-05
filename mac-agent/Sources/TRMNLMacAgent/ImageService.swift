import AppKit
import Foundation

enum SlideshowType: String {
    case portrait
    case landscape

    static func parse(_ rawValue: String?) throws -> SlideshowType {
        guard let rawValue, let type = SlideshowType(rawValue: rawValue) else {
            throw AgentError.usage("Missing or invalid --type. Use portrait or landscape.")
        }
        return type
    }
}

enum PhotoDelivery: String {
    case polling
    case webhook

    static func parse(_ rawValue: String?) throws -> PhotoDelivery {
        guard let rawValue else {
            return .polling
        }
        guard let delivery = PhotoDelivery(rawValue: rawValue) else {
            throw AgentError.usage("Invalid --delivery. Use polling or webhook.")
        }
        return delivery
    }
}

enum ImageService {
    static let displayWidth = 800
    static let displayHeight = 480
    static let maxUploadBytes = 450 * 1024

    static func loadImage(at path: String) throws -> NSImage {
        let url = URL(fileURLWithPath: path)
        guard let image = NSImage(contentsOf: url) else {
            throw AgentError.invalidImage(path)
        }
        return image
    }

    static func processJPEG(_ image: NSImage, quality: CGFloat = 0.85) throws -> Data {
        let processed = resize(image)
        guard
            let tiff = processed.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else {
            throw AgentError.invalidImage("processed image")
        }

        let qualities: [CGFloat] = [quality, 0.75, 0.65, 0.55, 0.45, 0.35, 0.25]
        for candidateQuality in qualities {
            guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: candidateQuality]) else {
                continue
            }
            if data.count <= maxUploadBytes {
                return data
            }
        }

        guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.2]) else {
            throw AgentError.invalidImage("processed image")
        }
        return data
    }

    static func orientation(of image: NSImage) -> SlideshowType {
        image.size.height > image.size.width ? .portrait : .landscape
    }

    private static func resize(_ image: NSImage) -> NSImage {
        let targetSize = NSSize(width: displayWidth, height: displayHeight)
        let imageSize = image.size
        let widthRatio = targetSize.width / imageSize.width
        let heightRatio = targetSize.height / imageSize.height
        let ratio = min(widthRatio, heightRatio)
        let scaledSize = NSSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
        let origin = NSPoint(
            x: (targetSize.width - scaledSize.width) / 2,
            y: (targetSize.height - scaledSize.height) / 2
        )

        let output = NSImage(size: targetSize)
        output.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: targetSize).fill()
        image.draw(
            in: NSRect(origin: origin, size: scaledSize),
            from: NSRect(origin: .zero, size: imageSize),
            operation: .copy,
            fraction: 1.0
        )
        output.unlockFocus()
        return output
    }
}
