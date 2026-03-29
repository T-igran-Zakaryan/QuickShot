import Foundation
import Photos

@MainActor
@Observable
final class DocumentsLibraryViewModel {
    var matchedAssetIdentifiers = Set<String>()
    var isScanning = false
    var progressCompletedCount = 0
    var progressTotalCount = 0
    var hasCompletedInitialScan = false
    var lastScannedAssetIdentifiers = Set<String>()
    var errorMessage: String?

    private var scanTask: Task<Void, Never>?

    var hasResults: Bool {
        !matchedAssetIdentifiers.isEmpty
    }

    func displayedAssets(from assets: [PHAsset]) -> [PHAsset] {
        assets.filter { matchedAssetIdentifiers.contains($0.localIdentifier) }
    }

    func hasLibraryChanges(comparedTo assets: [PHAsset]) -> Bool {
        Set(assets.map(\.localIdentifier)) != lastScannedAssetIdentifiers
    }

    func startScan(using assets: [PHAsset]) {
        let assetIdentifiers = assets.map(\.localIdentifier)

        scanTask?.cancel()
        errorMessage = nil
        isScanning = true
        progressCompletedCount = 0
        progressTotalCount = assetIdentifiers.count

        scanTask = Task(priority: .utility) { [assetIdentifiers] in
            let matchedIdentifiers = await DocumentLibraryScanner.scanDocumentAssetIdentifiers(
                from: assetIdentifiers
            ) { completed, total in
                await MainActor.run {
                    self.progressCompletedCount = completed
                    self.progressTotalCount = total
                }
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.matchedAssetIdentifiers = matchedIdentifiers
                self.lastScannedAssetIdentifiers = Set(assetIdentifiers)
                self.progressCompletedCount = self.progressTotalCount
                self.hasCompletedInitialScan = true
                self.isScanning = false
            }
        }
    }
}
