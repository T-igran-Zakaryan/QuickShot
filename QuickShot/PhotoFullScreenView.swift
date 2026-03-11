//
//  PhotoFullScreenView.swift
//  Images
//
//  Created by Тигран Закарян on 01.03.26.
//

import SwiftUI
import Photos

struct PhotoFullScreenView: View {
   @Environment(\.dismiss) private var dismiss
   let asset: PHAsset
   let imageManager: PHCachingImageManager
   @State private var image: UIImage?
   @State private var scale: CGFloat = 1
   @State private var lastScale: CGFloat = 1
   @State private var offset: CGSize = .zero
   @State private var accumulatedOffset: CGSize = .zero
   @State private var dismissDragOffset: CGSize = .zero
   private let doubleTapZoomScale: CGFloat = 2.5
   
   var body: some View {
      GeometryReader { proxy in
         ZStack {
            Color.black.ignoresSafeArea()
               .opacity(backgroundOpacity)
            
            if let image {
               Image(uiImage: image)
                  .resizable()
                  .scaledToFit()
                  .scaleEffect(scale)
                  .offset(combinedImageOffset)
                  .gesture(magnificationGesture(containerSize: proxy.size, image: image))
                  .simultaneousGesture(dragGesture(containerSize: proxy.size, image: image))
                  .highPriorityGesture(doubleTapZoomGesture(containerSize: proxy.size, image: image))
           } else {
               ProgressView()
            }
         }
      }
      .onAppear {
         loadImage()
      }
      .interactiveDismissDisabled(scale > 1)
   }

   
   /// Loads the full-resolution image for display.
   private func loadImage() {
      imageManager.requestImage(
         for: asset,
         targetSize: CGSize(
            width: CGFloat(asset.pixelWidth),
            height: CGFloat(asset.pixelHeight)
         ),
         contentMode: .aspectFill,
         options: nil
      ) { image, _ in
         self.image = image
      }
   }
   
   /// Handles pinch-to-zoom with sensible clamping.
   private func magnificationGesture(containerSize: CGSize, image: UIImage) -> some Gesture {
      MagnificationGesture()
         .onChanged { value in
            // Apply delta to current scale and clamp to 1x...4x.
            let delta = value / lastScale
            var newScale = scale * delta
            newScale = min(max(1, newScale), 4)
            scale = newScale
            lastScale = value
            offset = clampedOffset(offset, containerSize: containerSize, image: image, scale: scale)
            accumulatedOffset = offset
            dismissDragOffset = .zero
         }
         .onEnded { _ in
            lastScale = 1
            if scale <= 1 {
               withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                  scale = 1
                  offset = .zero
                  accumulatedOffset = .zero
               }
            }
         }
   }

   private func dragGesture(containerSize: CGSize, image: UIImage) -> some Gesture {
      DragGesture()
         .onChanged { value in
            guard scale > 1 else {
               dismissDragOffset = value.translation
               return
            }
            let candidate = CGSize(
               width: accumulatedOffset.width + value.translation.width,
               height: accumulatedOffset.height + value.translation.height
            )
            offset = clampedOffset(candidate, containerSize: containerSize, image: image, scale: scale)
         }
         .onEnded { value in
            guard scale > 1 else {
               let predictedY = value.predictedEndTranslation.height
               let translationY = value.translation.height
               let shouldDismiss = abs(predictedY) > 240 || abs(translationY) > 140
               if shouldDismiss {
                  dismiss()
               } else {
                  withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                     dismissDragOffset = .zero
                  }
               }
               offset = .zero
               accumulatedOffset = .zero
               return
            }

            let momentum = CGSize(
               width: value.predictedEndTranslation.width - value.translation.width,
               height: value.predictedEndTranslation.height - value.translation.height
            )
            let projected = CGSize(
               width: offset.width + (momentum.width * 0.35),
               height: offset.height + (momentum.height * 0.35)
            )
            let target = clampedOffset(projected, containerSize: containerSize, image: image, scale: scale)

            withAnimation(.interpolatingSpring(stiffness: 140, damping: 20)) {
               offset = target
            }
            accumulatedOffset = target
         }
   }

   /// Toggles zoom level on double tap to avoid drag/swipe conflicts.
   private func doubleTapZoomGesture(containerSize: CGSize, image: UIImage) -> some Gesture {
      TapGesture(count: 2)
         .onEnded {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
               scale = scale > 1 ? 1 : doubleTapZoomScale
               lastScale = 1
               dismissDragOffset = .zero
               if scale == 1 {
                  offset = .zero
                  accumulatedOffset = .zero
               } else {
                  offset = clampedOffset(offset, containerSize: containerSize, image: image, scale: scale)
                  accumulatedOffset = offset
               }
            }
         }
   }

   private func clampedOffset(_ candidate: CGSize, containerSize: CGSize, image: UIImage, scale: CGFloat) -> CGSize {
      let imageSize = image.size
      guard imageSize.width > 0, imageSize.height > 0 else { return .zero }

      let fitScale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
      let fittedSize = CGSize(width: imageSize.width * fitScale, height: imageSize.height * fitScale)
      let zoomedSize = CGSize(width: fittedSize.width * scale, height: fittedSize.height * scale)

      let maxX = max((zoomedSize.width - containerSize.width) / 2, 0)
      let maxY = max((zoomedSize.height - containerSize.height) / 2, 0)

      return CGSize(
         width: min(max(candidate.width, -maxX), maxX),
         height: min(max(candidate.height, -maxY), maxY)
      )
   }

   private var combinedImageOffset: CGSize {
      if scale > 1 {
         return offset
      }
      return CGSize(
         width: dismissDragOffset.width * 0.18,
         height: dismissDragOffset.height
      )
   }

   private var backgroundOpacity: Double {
      guard scale == 1 else { return 1 }
      let progress = min(abs(dismissDragOffset.height) / 320, 1)
      return 1 - (progress * 0.45)
   }
}
