//
//  PhotoFullScreenView.swift
//  Images
//
//  Created by Тигран Закарян on 01.03.26.
//

import SwiftUI
import Photos

struct ImageDetailView: View {
    let asset: PHAsset
    let imageManager: PHCachingImageManager
    @Binding var isZoomed: Bool
    @State private var image: UIImage?
    @State private var isShowingInfoSheet = false
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero
    private let doubleTapZoomScale: CGFloat = 2.5
   
   var body: some View {
      GeometryReader { proxy in
        ZStack {
//            Color.black.ignoresSafeArea()
//               .opacity(backgroundOpacity)
            
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
                    .scaleEffect(scale)
                    .offset(offset)
                    .simultaneousGesture(
                        dragGesture(containerSize: proxy.size, image: image),
                        including: scale > 1 ? .all : .subviews
                    )
                    .highPriorityGesture(doubleTapZoomGesture(containerSize: proxy.size, image: image))
                  
            } else {
                ProgressView()
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button {
                        isShowingInfoSheet = true
                    } label: {
                        Image(systemName: "info.circle.fill")
//                            .font(.title3)
//                            .foregroundStyle(.primary)
                            .padding(10)
                            .glassEffect(.regular, in: Circle())
                    }
                    .accessibilityLabel("Image details")
                }
                .padding(.top, 12)
                .padding(.trailing, 12)
                Spacer()
            }
        }
      }
      .onAppear {
         loadImage()
         isZoomed = scale > 1
      }
      .onDisappear {
         isZoomed = false
      }
      .onChange(of: scale) { _, newValue in
         isZoomed = newValue > 1
      }
      .sheet(isPresented: $isShowingInfoSheet) {
         ImageInfoSheetView(asset: asset)
      }
      
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
   
    private func dragGesture(containerSize: CGSize, image: UIImage) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                let candidate = CGSize(
                    width: accumulatedOffset.width + value.translation.width,
                    height: accumulatedOffset.height + value.translation.height
                )
                offset = clampedOffset(candidate, containerSize: containerSize, image: image, scale: scale)
            }
            .onEnded { value in
                guard scale > 1 else { return }

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

    // Background opacity/dismiss offsets removed with fullscreen gestures.
}
