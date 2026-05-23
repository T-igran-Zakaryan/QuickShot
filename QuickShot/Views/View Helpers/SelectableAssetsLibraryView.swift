import SwiftUI
import Photos

struct SelectableAssetsLibraryView<ExtraToolbar: ToolbarContent, GridBottomOverlay: View>: View {
    @Environment(\.displayScale) private var displayScale
    @AppStorage("useSelectionOrder") private var useSelectionOrder = false

    let title: String
    let subtitle: String
    let assets: [PHAsset]
    let imageManager: PHCachingImageManager
    let autoScrollToBottom: Bool
    let convertAction: ([PHAsset], PDFConversionSettings) async -> Void
    @ToolbarContentBuilder let extraToolbar: () -> ExtraToolbar
    @ViewBuilder let gridBottomOverlay: () -> GridBottomOverlay

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
    @State private var imageHeight: CGFloat = 120

    private let gridBottomAnchorID = "grid-bottom-anchor"
    private let gridItemCount = 3

    private var shouldShowConvertButton: Bool {
        isSelectionMode
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let cellSide = (proxy.size.width / 4).rounded(.down)
                let targetScale = displayScale * 1.5
                let targetSize = CGSize(width: cellSide * targetScale, height: cellSide * targetScale)

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        PhotoAssetGridContent(
                            assets: assets,
                            imageManager: imageManager,
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
                        guard autoScrollToBottom else { return }
                        didScrollToBottom = false
                        DispatchQueue.main.async {
                            scrollToBottomIfNeeded(using: scrollProxy)
                        }
                    }
                    .onChange(of: assets.count) { _, _ in
                        guard autoScrollToBottom else { return }
                        DispatchQueue.main.async {
                            scrollToBottomIfNeeded(using: scrollProxy)
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    gridBottomOverlay()
                }
            }
            .navigationTitle(title)
            .navigationSubtitle(subtitle)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        toggleSelectionMode()
                    } label: {
                        Image(systemName: isSelectionMode ? "checkmark.circle" : "circle.grid.2x2.topleft.checkmark.filled")
                    }
                    .disabled(assets.isEmpty)
                }
                extraToolbar()
            }
            .overlay(alignment: .bottom) {
                if shouldShowConvertButton {
                    ConvertToPDFButton(
                        selectedCount: selectedAssetIDs.count,
                        isConverting: isConverting
                    ) {
                        isShowingConversionSheet = true
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: shouldShowConvertButton)
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
            .fullScreenCover(item: $selectedAsset) { selection in
                ImageDetailView(
                    asset: selection.asset,
                    imageManager: imageManager,
                    isZoomed: $isZoomedInFullScreen
                )
                .navigationTransition(.zoom(sourceID: selection.id, in: namespace))
                .interactiveDismissDisabled(isZoomedInFullScreen)
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
    private func handleLongPress(on asset: PHAsset) {
        if !isSelectionMode {
            isSelectionMode = true
        }

        toggleSelection(for: asset)
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
                assets.first { $0.localIdentifier == id }
            }
        } else {
            selectedAssets = assets.filter { selectedAssetIDs.contains($0.localIdentifier) }
        }

        let settings = PDFConversionSettings(
            pageSize: conversionPageSize,
            compressionQuality: CGFloat(compressionQuality)
        )

        await convertAction(selectedAssets, settings)

        isConverting = false
        selectedAssetIDs.removeAll()
        selectedAssetOrder.removeAll()
        isSelectionMode = false
        isShowingConversionSheet = false
    }

    private func scrollToBottomIfNeeded(using scrollProxy: ScrollViewProxy) {
        guard !didScrollToBottom, !assets.isEmpty else {
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
            .foregroundColor(isSelected ? .blue : .white)
            .padding(6)
    }
}

extension SelectableAssetsLibraryView where ExtraToolbar == EmptyToolbarContent, GridBottomOverlay == EmptyView {
    init(
        title: String,
        subtitle: String,
        assets: [PHAsset],
        imageManager: PHCachingImageManager,
        autoScrollToBottom: Bool = false,
        convertAction: @escaping ([PHAsset], PDFConversionSettings) async -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.assets = assets
        self.imageManager = imageManager
        self.autoScrollToBottom = autoScrollToBottom
        self.convertAction = convertAction
        self.extraToolbar = { EmptyToolbarContent() }
        self.gridBottomOverlay = { EmptyView() }
    }
}

struct EmptyToolbarContent: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) { }
    }
}
