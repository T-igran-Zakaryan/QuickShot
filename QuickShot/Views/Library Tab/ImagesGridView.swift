   //
   //  PhotoLibraryModel.swift
   //  Images
   //
   //  Created by Тигран Закарян on 01.03.26.
   //

import SwiftUI
import Photos


struct ImagesGridView: View {
   @Environment(\.displayScale) private var displayScale
   @AppStorage("useSelectionOrder") private var useSelectionOrder = false
   @State private var model = PhotoLibraryModel()
   @State private var pdfService = PDFLibraryService()
   @Namespace private var namespace
   
   @State private var selectedAsset: SelectedAsset?
   @State private var selectedAssetIDs: Set<String> = []
   @State private var selectedAssetOrder: [String] = []
   @State private var isSelectionMode = false
   @State private var isConverting = false
   @State private var isShowingConversionSheet = false
   @State private var conversionPageSize: PDFPageSizeOption = .a4
   @State private var compressionQuality: Double = 0.7
   @State private var didScrollToBottom = false
   @State private var isZoomedInFullScreen = false
   private let gridBottomAnchorID = "grid-bottom-anchor"
   
   private var shouldShowConvertButton: Bool {
      isSelectionMode
   }
   @State private var gridItemCount = 3
   @State var imageHeight: CGFloat = 120
   
   // 5 items = 80 height
   
   var body: some View {
      NavigationStack {
         GeometryReader { proxy in
            let cellSide = (proxy.size.width / 4).rounded(.down)
            let targetScale = displayScale * 1.5
            let targetSize = CGSize(width: cellSide * targetScale, height: cellSide * targetScale)
            
            ScrollViewReader { scrollProxy in
               ScrollView {
                  PhotoAssetGridContent(
                     assets: model.assets,
                     imageManager: model.imageManager,
                     targetSize: targetSize,
                     namespace: namespace,
                     gridItemCount: gridItemCount,
                     onTap: handleTap(on:),
                     onLongPress: handleLongPress(on:),
                     imageHeight: $imageHeight
                  ) { asset in
                     ZStack(alignment: .topTrailing) {
                        Rectangle()
                           .fill(Color.black.opacity(isSelectionMode ? 0.25 : 0))

                        if isSelectionMode {
                           selectionBadge(isSelected: selectedAssetIDs.contains(asset.localIdentifier))
                        }
                     }
                     .animation(.default, value: isSelectionMode)
                  }

                  Color.clear
                     .frame(height: 1)
                     .id(gridBottomAnchorID)
               }
               .onAppear {
                  didScrollToBottom = false
                  Task {
                     await model.requestAuthorization()
                     DispatchQueue.main.async {
                        scrollToBottomIfNeeded(using: scrollProxy)
                     }
                  }
               }
               .onChange(of: model.assets.count) { _, _ in
                  DispatchQueue.main.async {
                     scrollToBottomIfNeeded(using: scrollProxy)
                  }
               }
            }
         }
         .fullScreenCover(item: $selectedAsset) { selection in
            ImageDetailView(
               asset: selection.asset,
               imageManager: model.imageManager,
               isZoomed: $isZoomedInFullScreen
            )
            .navigationTransition(.zoom(sourceID: selection.id, in: namespace))
            .interactiveDismissDisabled(isZoomedInFullScreen)
         }
         
         .sheet(isPresented: $isShowingConversionSheet) {
            ConversionSettingsView(
               pageSize: $conversionPageSize,
               compressionQuality: $compressionQuality,
               useSelectionOrder: $useSelectionOrder,
               isConverting: $isConverting
            ) {
               await convertSelectedAssets()
            }
         }
         .navigationTitle("Images")
         .navigationSubtitle("\(model.assets.count) - elements")
         .toolbarTitleDisplayMode(.inlineLarge)
         .overlay(alignment: .bottom) {
            if shouldShowConvertButton {
               Button {
                  isShowingConversionSheet = true
               } label: {
                  Label("Convert to PDF", systemImage: "doc.badge.plus")
               }
               .buttonStyle(.glass)
               .disabled(selectedAssetIDs.isEmpty || isConverting)
               .padding(.horizontal)
               .padding(.bottom, 6)
               .transition(.move(edge: .bottom).combined(with: .opacity))
            }
         }
         .animation(.spring(response: 0.35, dampingFraction: 0.85), value: shouldShowConvertButton)
         .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
               Button {
                  toggleSelectionMode()
               } label: {
                  Image(systemName: isSelectionMode ? "checkmark.circle" :  "circle.grid.2x2.topleft.checkmark.filled")
               }
            }
//            ToolbarItemGroup {
//               Button("Minus", systemImage: "minus") {
//                  gridItemCount -= 2
//               }
//               .disabled(gridItemCount == 1 ? true : false)
//               
//               Button("Plus", systemImage: "plus") {
//                  gridItemCount += 2
//               }
//               .disabled(gridItemCount == 5 ? true : false)
//            }
         }
//         .onChange(of: gridItemCount) { _, newCount in
//            if newCount == 1 {
//               imageHeight = 500
//            } else if newCount == 3 {
//               imageHeight = 130
//            } else if newCount == 5 {
//               imageHeight = 80
//            }
//         }
      }
   }
   
   @MainActor
   private func handleTap(on asset: PHAsset) {
      if isSelectionMode {
         toggleSelection(for: asset)
         
      } else {
         selectedAsset = SelectedAsset(asset: asset)
      }
   }
   
   @MainActor
   private func toggleSelectionMode() {
      isSelectionMode.toggle()
      if !isSelectionMode {
         selectedAssetIDs.removeAll()
         selectedAssetOrder.removeAll()
      }
   }
   
   @MainActor
   private func toggleSelection(for asset: PHAsset) {
      let id = asset.localIdentifier
      if selectedAssetIDs.contains(id) {
         selectedAssetIDs.remove(id)
         if let index = selectedAssetOrder.firstIndex(of: id) {
            selectedAssetOrder.remove(at: index)
         }
      } else {
         selectedAssetIDs.insert(id)
         selectedAssetOrder.append(id)
      }
   }

   @MainActor
   private func handleLongPress(on asset: PHAsset) {
      if !isSelectionMode {
         isSelectionMode = true
      }

      toggleSelection(for: asset)
   }
   
   @MainActor
   private func convertSelectedAssets() async {
      guard !isConverting else { return }
      
      isConverting = true
      let selectedAssets: [PHAsset]
      if useSelectionOrder {
         selectedAssets = selectedAssetOrder.compactMap { id in
            model.assets.first { $0.localIdentifier == id }
         }
      } else {
         selectedAssets = model.assets.filter { selectedAssetIDs.contains($0.localIdentifier) }
      }
      
      let settings = PDFConversionSettings(
         pageSize: conversionPageSize,
         compressionQuality: CGFloat(compressionQuality)
      )
      
      if let data = await model.pdfData(from: selectedAssets, settings: settings) {
         _ = pdfService.savePDF(data: data)
      }
      
      isConverting = false
      selectedAssetIDs.removeAll()
      selectedAssetOrder.removeAll()
      isSelectionMode = false
      isShowingConversionSheet = false
   }
   
   private func scrollToBottomIfNeeded(using scrollProxy: ScrollViewProxy) {
      guard !didScrollToBottom, !model.assets.isEmpty else {
         return
      }
      withAnimation(.none) {
         scrollProxy.scrollTo(gridBottomAnchorID, anchor: .bottom)
      }
      didScrollToBottom = true
   }
   
   @ViewBuilder
   private func selectionBadge(isSelected: Bool) -> some View {
      Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
         .font(.title3)
         //         .symbolRenderingMode(.palette)
         //         .foregroundStyle(.white, isSelected ? .blue : .gray)
         .foregroundColor(isSelected ? .blue : .white)
         .padding(6)
   }
}
