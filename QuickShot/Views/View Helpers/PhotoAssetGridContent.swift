import Photos
import SwiftUI

struct PhotoAssetGridContent<Overlay: View>: View {
    let assets: [PHAsset]
    let imageManager: PHCachingImageManager
    let targetSize: CGSize
    let namespace: Namespace.ID
    let gridItemCount: Int
    let onTap: (PHAsset) -> Void
    let onLongPress: ((PHAsset) -> Void)?
    @Binding var imageHeight: CGFloat
    @ViewBuilder let overlay: (PHAsset) -> Overlay

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(spacing: 2), count: gridItemCount), spacing: 2) {
            ForEach(assets, id: \.localIdentifier) { asset in
                ZStack(alignment: .topTrailing) {
                    AssetThumbnailView(
                        asset: asset,
                        targetSize: targetSize,
                        imageManager: imageManager,
                        imageHeight: $imageHeight
                    )
                    .contentShape(Rectangle())
                    .matchedTransitionSource(id: asset.localIdentifier, in: namespace)

                    overlay(asset)
                }
                .onTapGesture {
                    onTap(asset)
                }
                .onLongPressGesture {
                    onLongPress?(asset)
                }
            }
        }
    }
}
