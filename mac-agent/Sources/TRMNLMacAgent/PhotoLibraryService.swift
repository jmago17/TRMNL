import AppKit
import Foundation
import Photos
import Vision

enum PhotoPickMode: String {
    case latest
    case random
    case best
}

struct SlideshowImageSelection {
    let landscape: [NSImage]
    let portrait: [NSImage]
}

final class PhotoLibraryService {
    private let bestCandidateLimit = 100

    func requestAccess() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            return
        }

        let requested = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard requested == .authorized || requested == .limited else {
            throw AgentError.photoAccessDenied
        }
    }

    func pickImage(albumName: String?, mode: PhotoPickMode) async throws -> NSImage {
        let selected = await orderedAssets(fetchAssets(albumName: albumName), mode: mode).first

        guard let selected else {
            throw AgentError.noPhotosFound
        }
        return try await image(for: selected)
    }

    func pickImages(albumName: String?, type: SlideshowType, limit: Int, mode: PhotoPickMode = .latest) async throws -> [NSImage] {
        let matchingAssets = fetchAssets(albumName: albumName).filter { asset in
            let isPortrait = asset.pixelHeight > asset.pixelWidth
            return (type == .portrait && isPortrait) || (type == .landscape && !isPortrait)
        }
        let assets = await orderedAssets(matchingAssets, mode: mode)
        var images: [NSImage] = []

        for asset in assets {
            guard images.count < limit else {
                break
            }

            images.append(try await image(for: asset))
        }

        guard !images.isEmpty else {
            throw AgentError.noPhotosFound
        }
        return images
    }

    func pickSlideshowImages(albumName: String?, limitPerType: Int, mode: PhotoPickMode = .random) async throws -> SlideshowImageSelection {
        let assets = await orderedAssets(fetchAssets(albumName: albumName), mode: mode)
        var landscape: [NSImage] = []
        var portrait: [NSImage] = []

        for asset in assets {
            guard landscape.count < limitPerType || portrait.count < limitPerType else {
                break
            }

            let isPortrait = asset.pixelHeight > asset.pixelWidth
            if isPortrait, portrait.count < limitPerType {
                portrait.append(try await image(for: asset))
            } else if !isPortrait, landscape.count < limitPerType {
                landscape.append(try await image(for: asset))
            }
        }

        guard !landscape.isEmpty || !portrait.isEmpty else {
            throw AgentError.noPhotosFound
        }
        return SlideshowImageSelection(landscape: landscape, portrait: portrait)
    }

    private func fetchAssets(albumName: String?) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(
            format: "mediaType == %d AND NOT ((mediaSubtypes & %d) != 0)",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )

        let result: PHFetchResult<PHAsset>
        if let albumName, !albumName.isEmpty, let collection = findAlbum(named: albumName) {
            result = PHAsset.fetchAssets(in: collection, options: options)
        } else {
            result = PHAsset.fetchAssets(with: options)
        }

        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    private func orderedAssets(_ assets: [PHAsset], mode: PhotoPickMode) async -> [PHAsset] {
        switch mode {
        case .latest:
            return assets
        case .random:
            return assets.shuffled()
        case .best:
            return await bestAssets(from: assets)
        }
    }

    private func bestAssets(from assets: [PHAsset]) async -> [PHAsset] {
        let candidates = Array(assets.shuffled().prefix(bestCandidateLimit))
        guard #available(macOS 15.0, *) else {
            return candidates
        }

        var scored: [(asset: PHAsset, score: Float)] = []
        scored.reserveCapacity(candidates.count)

        for asset in candidates {
            guard let score = await aestheticScore(for: asset) else {
                continue
            }
            scored.append((asset, score))
        }

        guard !scored.isEmpty else {
            return candidates
        }

        return scored
            .sorted { $0.score > $1.score }
            .map(\.asset)
    }

    @available(macOS 15.0, *)
    private func aestheticScore(for asset: PHAsset) async -> Float? {
        await withCheckedContinuation { continuation in
            let lock = NSLock()
            var didResume = false
            var requestID = PHInvalidImageRequestID

            func resumeOnce(_ score: Float?) {
                lock.lock()
                guard !didResume else {
                    lock.unlock()
                    return
                }
                didResume = true
                let id = requestID
                lock.unlock()

                if id != PHInvalidImageRequestID {
                    PHImageManager.default().cancelImageRequest(id)
                }
                continuation.resume(returning: score)
            }

            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = false

            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                resumeOnce(nil)
            }

            requestID = PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 512, height: 512),
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if (info?[PHImageCancelledKey] as? Bool) == true {
                    resumeOnce(nil)
                    return
                }
                if info?[PHImageErrorKey] != nil {
                    resumeOnce(nil)
                    return
                }
                guard let image else {
                    resumeOnce(nil)
                    return
                }

                var rect = NSRect(origin: .zero, size: image.size)
                guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
                    resumeOnce(nil)
                    return
                }

                let request = VNCalculateImageAestheticsScoresRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage)

                do {
                    try handler.perform([request])
                    resumeOnce(request.results?.first?.overallScore)
                } catch {
                    resumeOnce(nil)
                }
            }
        }
    }

    private func findAlbum(named albumName: String) -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "localizedTitle == %@", albumName)

        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
        if let album = userAlbums.firstObject {
            return album
        }

        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: options)
        return smartAlbums.firstObject
    }

    private func image(for asset: PHAsset) async throws -> NSImage {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.isNetworkAccessAllowed = true

            let size = CGSize(width: ImageService.displayWidth * 2, height: ImageService.displayHeight * 2)
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if (info?[PHImageResultIsDegradedKey] as? Bool) == true {
                    return
                }
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let image else {
                    continuation.resume(throwing: AgentError.invalidImage(asset.localIdentifier))
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }
}
