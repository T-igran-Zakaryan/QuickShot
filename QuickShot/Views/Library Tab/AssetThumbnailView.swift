//
//  AssetThumbnailView.swift
//  Images
//
//  Created by Тигран Закарян on 01.03.26.
//

import SwiftUI
import Photos

struct AssetThumbnailView: View {
   let asset: PHAsset
   let targetSize: CGSize
   let imageManager: PHCachingImageManager

   @State private var image: UIImage?
   @Binding var imageHeight: CGFloat

   var body: some View {
      GeometryReader {
         let size = $0.size

         Group {
            if let image {
               Image(uiImage: image)
                  .resizable()
                  .scaledToFill()
                  .frame(width: size.width, height: size.height)
                  .clipped()
            } else {
               Color.gray.opacity(0.2)
            }
         }
      }
      .frame(height: imageHeight)
      .clipShape(RoundedRectangle(cornerRadius: 2))

      .onAppear {
            // Кешируем конкретный элемент
         imageManager.startCachingImages(
            for: [asset],
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
         )

         let fastOptions = PHImageRequestOptions()
         fastOptions.deliveryMode = .fastFormat
         fastOptions.resizeMode = .fast
         fastOptions.isNetworkAccessAllowed = true

         imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: fastOptions
         ) { image, _ in
            DispatchQueue.main.async {
               self.image = image
            }
         }

         let highQualityOptions = PHImageRequestOptions()
         highQualityOptions.deliveryMode = .highQualityFormat
         highQualityOptions.resizeMode = .fast
         highQualityOptions.isNetworkAccessAllowed = true

         imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: highQualityOptions
         ) { image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            guard !isDegraded else { return }

            DispatchQueue.main.async {
               self.image = image
            }
         }
      }
      .onDisappear {
            // Останавливаем кеш для элемента
         imageManager.stopCachingImages(
            for: [asset],
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
         )
      }
   }
}
