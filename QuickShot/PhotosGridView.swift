   //
   //  PhotoLibraryModel.swift
   //  Images
   //
   //  Created by Тигран Закарян on 01.03.26.
   //


import SwiftUI
import Photos

   /// Wrapper to give PHAsset identity without retroactive conformance.
private struct SelectedAsset: Identifiable {
   let asset: PHAsset
   var id: String { asset.localIdentifier }
}

struct AssetGridView: View {
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
   @State private var didScrollToBottom = false
   private let gridBottomAnchorID = "grid-bottom-anchor"
   
   var body: some View {
      NavigationStack {
         GeometryReader { proxy in
            let cellSide = (proxy.size.width / 4).rounded(.down)
            let targetScale = displayScale * 1.5
            let targetSize = CGSize(width: cellSide * targetScale, height: cellSide * targetScale)
            
            ScrollViewReader { scrollProxy in
               ScrollView {
                  LazyVGrid(columns: Array(repeating: GridItem(spacing: 2), count: 3), spacing: 2) {
                     ForEach(model.assets, id: \.localIdentifier) { asset in
                        ZStack(alignment: .topTrailing) {
                           AssetThumbnailView(
                              asset: asset,
                              targetSize: targetSize,
                              imageManager: model.imageManager
                           )
                           .contentShape(Rectangle())
                           
                           .matchedTransitionSource(id: asset.localIdentifier, in: namespace)
                           
                           Rectangle()
                              .fill(Color.black.opacity(isSelectionMode ? 0.35 : 0.15))
                           
                           if isSelectionMode {
                              selectionBadge(isSelected: selectedAssetIDs.contains(asset.localIdentifier))
                           }
                        }
                        .onTapGesture {
                           handleTap(on: asset)
                        }
                        .animation(.default, value: isSelectionMode)
                     }
                     Color.clear
                        .frame(height: 1)
                        .id(gridBottomAnchorID)
                  }
                  
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
            PhotoFullScreenView(asset: selection.asset, imageManager: model.imageManager)
               .navigationTransition(.zoom(sourceID: selection.id, in: namespace))
         }
         .navigationTitle("Photos")
         .navigationSubtitle("\(model.assets.count) - elements")
         .toolbarTitleDisplayMode(.inlineLarge)
         .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
               Button {
                  Task { await convertSelectedAssets() }
               } label: {
                  Image(systemName: "arrow.up.document.fill")
               }
               .disabled(selectedAssetIDs.isEmpty || isConverting)
            }
            ToolbarItem(placement: .topBarTrailing) {
               Button {
                  toggleSelectionMode()
               } label: {
                  Image(systemName: isSelectionMode ? "checkmark.circle" :  "circle.grid.2x2.topleft.checkmark.filled")
               }
            }
         }
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
      
      if let data = await model.pdfData(from: selectedAssets) {
         _ = pdfService.savePDF(data: data)
      }
      
      isConverting = false
      selectedAssetIDs.removeAll()
      selectedAssetOrder.removeAll()
      isSelectionMode = false
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
