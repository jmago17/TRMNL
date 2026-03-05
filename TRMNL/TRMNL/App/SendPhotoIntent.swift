import AppIntents
import UIKit

struct SendPhotoToTRMNL: AppIntent {
    static var title: LocalizedStringResource = "Send Photo to TRMNL"
    static var description = IntentDescription("Dithers a photo and sends it to your TRMNL e-ink display.")

    @Parameter(title: "Photo")
    var photo: IntentFile

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let uiImage = UIImage(data: photo.data) else {
            throw SendPhotoError.invalidImage
        }

        let imageService = ImageProcessingService()
        let processed = await imageService.processForDisplay(uiImage)
        guard let jpegData = await imageService.jpegData(from: processed) else {
            throw SendPhotoError.processingFailed
        }
        let imageURL = try await CloudflareUploadService().upload(imageData: jpegData, filename: "photo.jpg")
        try await TRMNLWebhookService().sendPhoto(imageURL: imageURL)

        return .result(dialog: "Photo sent to your TRMNL display!")
    }
}

struct UploadPortraitSlideshow: AppIntent {
    static var title: LocalizedStringResource = "Upload Portrait Slideshow to TRMNL"
    static var description = IntentDescription("Uploads up to 5 portrait photos to your TRMNL slideshow.")

    @Parameter(title: "Photos", description: "Up to 5 portrait photos.")
    var photos: [IntentFile]

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let count = try await uploadSlideshow(photos, type: .portrait)
        return .result(dialog: "\(count) portrait(s) uploaded to TRMNL.")
    }
}

struct UploadLandscapeSlideshow: AppIntent {
    static var title: LocalizedStringResource = "Upload Landscape Slideshow to TRMNL"
    static var description = IntentDescription("Uploads up to 5 landscape photos to your TRMNL slideshow.")

    @Parameter(title: "Photos", description: "Up to 5 landscape photos.")
    var photos: [IntentFile]

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let count = try await uploadSlideshow(photos, type: .landscape)
        return .result(dialog: "\(count) landscape(s) uploaded to TRMNL.")
    }
}

struct CheckPhotoOrientation: AppIntent {
    static var title: LocalizedStringResource = "Check Photo Orientation"
    static var description = IntentDescription("Returns whether a photo is portrait or landscape.")

    @Parameter(title: "Photo")
    var photo: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<SlideshowType> {
        guard let uiImage = UIImage(data: photo.data) else {
            throw SendPhotoError.invalidImage
        }
        let orientation: SlideshowType = uiImage.size.height > uiImage.size.width ? .portrait : .landscape
        return .result(value: orientation)
    }
}

private func uploadSlideshow(_ photos: [IntentFile], type: SlideshowType) async throws -> Int {
    guard !photos.isEmpty else { throw SlideshowError.noPhotos }
    let imageService = ImageProcessingService()
    let uploadService = CloudflareUploadService()
    var uploadedCount = 0
    for (index, file) in photos.prefix(5).enumerated() {
        guard let uiImage = UIImage(data: file.data) else { continue }
        let processed = await imageService.processForDisplay(uiImage)
        guard let jpegData = await imageService.jpegData(from: processed) else { continue }
        _ = try await uploadService.upload(imageData: jpegData, filename: "\(type.rawValue)-\(index + 1).jpg")
        uploadedCount += 1
    }
    return uploadedCount
}

private enum SlideshowError: Error, LocalizedError {
    case noPhotos
    var errorDescription: String? { "No photos provided." }
}

private enum SendPhotoError: Error, LocalizedError {
    case invalidImage
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not load the provided image."
        case .processingFailed: return "Failed to process the image."
        }
    }
}
