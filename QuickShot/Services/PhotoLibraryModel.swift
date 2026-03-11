//
//  PhotoLibraryModel.swift
//  Images
//
//  Created by Тигран Закарян on 01.03.26.
//

import Foundation
import Photos
import UIKit

@Observable
final class PhotoLibraryModel: NSObject, PHPhotoLibraryChangeObserver {
    var assets: [PHAsset] = []
    var authStatus: PHAuthorizationStatus = .notDetermined
    let imageManager = PHCachingImageManager()
    private var fetchResult: PHFetchResult<PHAsset>?
   
    func loadAssets() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.includeHiddenAssets = false
        let result = PHAsset.fetchAssets(with: .image, options: options)
        fetchResult = result
        assets = result.objects(at: IndexSet(0..<result.count))
    }
   
    override init() {
        super.init()
        authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        PHPhotoLibrary.shared().register(self)
    }
   
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func requestAuthorization() async {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        await MainActor.run {
            self.authStatus = currentStatus
        }
        switch currentStatus {
        case .authorized, .limited:
            await MainActor.run {
                self.startObservingAndInitialFetch()
            }
            return
        case .notDetermined:
            break
        default:
            return
        }

        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    self.authStatus = status
                    switch status {
                    case .authorized, .limited:
                        self.startObservingAndInitialFetch()
                    default:
                        break
                    }
                    continuation.resume()
                }
            }
        }
    }

    @MainActor
    private func startObservingAndInitialFetch() {
        loadAssets()
    }
   
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            guard let fetchResult else { return }
            guard let details = changeInstance.changeDetails(for: fetchResult) else { return }

            let updatedResult = details.fetchResultAfterChanges
            self.fetchResult = updatedResult

            if details.hasMoves {
                self.assets = updatedResult.objects(at: IndexSet(0..<updatedResult.count))
                return
            }

            var updatedAssets = self.assets

            if let removedIndexes = details.removedIndexes, !removedIndexes.isEmpty {
                for index in removedIndexes.sorted(by: >) {
                    updatedAssets.remove(at: index)
                }
            }

            if let insertedIndexes = details.insertedIndexes, !insertedIndexes.isEmpty {
                for index in insertedIndexes.sorted() {
                    updatedAssets.insert(updatedResult.object(at: index), at: index)
                }
            }

            if let changedIndexes = details.changedIndexes, !changedIndexes.isEmpty {
                for index in changedIndexes {
                    updatedAssets[index] = updatedResult.object(at: index)
                }
            }

            self.assets = updatedAssets
        }
    }

    func fullResolutionImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .none

            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                guard let data, let image = UIImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }

    func pdfData(from assets: [PHAsset]) async -> Data? {
        guard !assets.isEmpty else { return nil }

        var images: [UIImage] = []
        images.reserveCapacity(assets.count)

        for asset in assets {
            if let image = await fullResolutionImage(for: asset) {
                images.append(image)
            }
        }

        return makePDF(from: images)
    }

    private func makePDF(from images: [UIImage]) -> Data? {
        guard !images.isEmpty else { return nil }

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, .zero, nil)

        for image in images {
            let size = image.size
            guard size.width > 0, size.height > 0 else { continue }

            let pageRect = CGRect(origin: .zero, size: size)
            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)

            image.draw(in: pageRect)
        }

        UIGraphicsEndPDFContext()
        return data as Data
    }
}
