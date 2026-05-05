import AppKit
import Foundation
import Photos

enum PhotoPickMode: String {
    case latest
    case random
}

struct SlideshowImageSelection {
    let landscape: [NSImage]
    let portrait: [NSImage]
}

final class PhotoLibraryService {
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
        let assets = fetchAssets(albumName: albumName)
        let selected: PHAsset?
        switch mode {
        case .latest:
            selected = assets.first
        case .random:
            selected = assets.randomElement()
        }

        guard let selected else {
            throw AgentError.noPhotosFound
        }
        return try await image(for: selected)
    }

    func pickImages(albumName: String?, type: SlideshowType, limit: Int, mode: PhotoPickMode = .latest) async throws -> [NSImage] {
        let assets = orderedAssets(fetchAssets(albumName: albumName), mode: mode)
        var images: [NSImage] = []

        for asset in assets {
            guard images.count < limit else {
                break
            }

            let isPortrait = asset.pixelHeight > asset.pixelWidth
            guard (type == .portrait && isPortrait) || (type == .landscape && !isPortrait) else {
                continue
            }
            images.append(try await image(for: asset))
        }

        guard !images.isEmpty else {
            throw AgentError.noPhotosFound
        }
        return images
    }

    func pickSlideshowImages(albumName: String?, limitPerType: Int, mode: PhotoPickMode = .random) async throws -> SlideshowImageSelection {
        let assets = orderedAssets(fetchAssets(albumName: albumName), mode: mode)
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

    private func orderedAssets(_ assets: [PHAsset], mode: PhotoPickMode) -> [PHAsset] {
        switch mode {
        case .latest:
            return assets
        case .random:
            return assets.shuffled()
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
