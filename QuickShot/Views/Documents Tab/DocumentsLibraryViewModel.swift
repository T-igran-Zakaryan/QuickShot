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
    private let defaults = UserDefaults.standard
    private let persistenceKey = "documentsLibraryScanCache"

    init() {
        loadPersistedState()
    }

    var hasResults: Bool {
        !matchedAssetIdentifiers.isEmpty
    }

    func displayedAssets(from assets: [PHAsset]) -> [PHAsset] {
        assets.filter { matchedAssetIdentifiers.contains($0.localIdentifier) }
    }

    func hasLibraryChanges(comparedTo assets: [PHAsset]) -> Bool {
        Set(assets.map(\.localIdentifier)) != lastScannedAssetIdentifiers
    }

    func hasUnscannedAssets(comparedTo assets: [PHAsset]) -> Bool {
        !unscannedAssetIdentifiers(from: assets).isEmpty
    }

    func reconcile(with assets: [PHAsset]) {
        let currentIdentifiers = Set(assets.map(\.localIdentifier))

        matchedAssetIdentifiers = matchedAssetIdentifiers.intersection(currentIdentifiers)
        lastScannedAssetIdentifiers = lastScannedAssetIdentifiers.intersection(currentIdentifiers)

        if !currentIdentifiers.isEmpty {
            hasCompletedInitialScan = hasCompletedInitialScan || !lastScannedAssetIdentifiers.isEmpty
        }

        persistState()
    }

    func startScan(using assets: [PHAsset]) {
        let assetIdentifiersToScan: [String]
        let updatedScannedAssetIdentifiers: Set<String>
        let currentAssetIdentifiers = Set(assets.map(\.localIdentifier))

        if hasCompletedInitialScan {
            assetIdentifiersToScan = unscannedAssetIdentifiers(from: assets)
            updatedScannedAssetIdentifiers = lastScannedAssetIdentifiers.union(assetIdentifiersToScan)
        } else {
            assetIdentifiersToScan = assets.map(\.localIdentifier)
            updatedScannedAssetIdentifiers = currentAssetIdentifiers
        }

        scanTask?.cancel()
        errorMessage = nil
        progressCompletedCount = 0
        progressTotalCount = assetIdentifiersToScan.count

        if assetIdentifiersToScan.isEmpty {
            matchedAssetIdentifiers = matchedAssetIdentifiers.intersection(currentAssetIdentifiers)
            lastScannedAssetIdentifiers = currentAssetIdentifiers
            hasCompletedInitialScan = !currentAssetIdentifiers.isEmpty || hasCompletedInitialScan
            isScanning = false
            persistState()
            return
        }

        isScanning = true

        scanTask = Task(priority: .utility) { [assetIdentifiersToScan, updatedScannedAssetIdentifiers, currentAssetIdentifiers] in
            let newlyMatchedIdentifiers = await DocumentLibraryScanner.scanDocumentAssetIdentifiers(
                from: assetIdentifiersToScan
            ) { completed, total in
                await MainActor.run {
                    self.progressCompletedCount = completed
                    self.progressTotalCount = total
                }
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.matchedAssetIdentifiers = self.matchedAssetIdentifiers
                    .intersection(currentAssetIdentifiers)
                    .union(newlyMatchedIdentifiers)
                self.lastScannedAssetIdentifiers = updatedScannedAssetIdentifiers
                self.progressCompletedCount = self.progressTotalCount
                self.hasCompletedInitialScan = true
                self.isScanning = false
                self.persistState()
            }
        }
    }

    private func unscannedAssetIdentifiers(from assets: [PHAsset]) -> [String] {
        assets
            .map(\.localIdentifier)
            .filter { !lastScannedAssetIdentifiers.contains($0) }
    }

    private func loadPersistedState() {
        guard let data = defaults.data(forKey: persistenceKey) else { return }
        guard let state = try? JSONDecoder().decode(PersistedDocumentsState.self, from: data) else { return }

        matchedAssetIdentifiers = Set(state.matchedAssetIdentifiers)
        lastScannedAssetIdentifiers = Set(state.lastScannedAssetIdentifiers)
        hasCompletedInitialScan = state.hasCompletedInitialScan
    }

    private func persistState() {
        let state = PersistedDocumentsState(
            matchedAssetIdentifiers: Array(matchedAssetIdentifiers),
            lastScannedAssetIdentifiers: Array(lastScannedAssetIdentifiers),
            hasCompletedInitialScan: hasCompletedInitialScan
        )

        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: persistenceKey)
    }
}

private struct PersistedDocumentsState: Codable {
    let matchedAssetIdentifiers: [String]
    let lastScannedAssetIdentifiers: [String]
    let hasCompletedInitialScan: Bool
}
