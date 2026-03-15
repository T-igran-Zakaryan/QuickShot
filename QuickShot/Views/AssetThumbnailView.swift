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
      .frame(height: 130)
      .clipShape(RoundedRectangle(cornerRadius: 2))

      .onAppear {
            // Кешируем конкретный элемент
         imageManager.startCachingImages(
            for: [asset],
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
         )

         imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
         ) { image, _ in
            self.image = image
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
