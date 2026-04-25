import SwiftUI
import Photos

struct DocumentsView: View {
    @Environment(\.displayScale) private var displayScale
    @AppStorage("useSelectionOrder") private var useSelectionOrder = false
    @State private var model = PhotoLibraryModel()
    @State private var viewModel = DocumentsLibraryViewModel()
    @State private var pdfService = PDFLibraryService()
    @State private var selectedAsset: SelectedAsset?
    @State private var selectedAssetIDs: Set<String> = []
    @State private var selectedAssetOrder: [String] = []
    @State private var isSelectionMode = false
    @State private var isConverting = false
    @State private var isShowingConversionSheet = false
    @State private var conversionPageSize: PDFPageSizeOption = .a4
    @State private var compressionQuality: Double = 0.7
    @State private var isZoomedInFullScreen = false
    @State private var imageHeight: CGFloat = 80
    @Namespace private var namespace

    private let gridItemCount = 5

    private var documentAssets: [PHAsset] {
        viewModel.displayedAssets(from: model.assets)
    }

    private var shouldShowConvertButton: Bool {
        isSelectionMode
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model.authStatus {
                case .authorized, .limited:
                    authorizedContent
                case .denied, .restricted:
                    ContentUnavailableView(
                        "Photo Access Required",
                        systemImage: "photo.badge.exclamationmark",
                        description: Text("Allow photo library access to scan for document-looking images.")
                    )
                case .notDetermined:
                    ProgressView("Loading Library")
                @unknown default:
                    ProgressView("Loading Library")
                }
            }
            .navigationTitle("Documents")
            .navigationSubtitle(navigationSubtitle)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
               
               Group {
                  if viewModel.hasCompletedInitialScan {
                  ToolbarItem(placement: .topBarTrailing) {
                     Button {
                        toggleSelectionMode()
                     } label: {
                        Image(systemName: isSelectionMode ? "checkmark.circle" : "circle.grid.2x2.topleft.checkmark.filled")
                     }
                     .disabled(documentAssets.isEmpty)
                  }
                  
                     ToolbarItem(placement: .topBarTrailing) {
                        Button("Refresh", systemImage: "arrow.clockwise") {
                           viewModel.startScan(using: model.assets)
                        }
                        .disabled(
                           viewModel.isScanning ||
                           model.assets.isEmpty ||
                           !canScanLibrary ||
                           !viewModel.hasUnscannedAssets(comparedTo: model.assets)
                        )
                     }
                  }
               }
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button {
//                        toggleSelectionMode()
//                    } label: {
//                        Image(systemName: isSelectionMode ? "checkmark.circle" : "circle.grid.2x2.topleft.checkmark.filled")
//                    }
//                    .disabled(documentAssets.isEmpty)
//                }
//
//                if viewModel.hasCompletedInitialScan {
//                    ToolbarItem(placement: .topBarTrailing) {
//                        Button("Refresh", systemImage: "arrow.clockwise") {
//                            viewModel.startScan(using: model.assets)
//                        }
//                        .disabled(
//                            viewModel.isScanning ||
//                            model.assets.isEmpty ||
//                            !canScanLibrary ||
//                            !viewModel.hasUnscannedAssets(comparedTo: model.assets)
//                        )
//                    }
//                }
            }
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
            .task {
                await model.requestAuthorization()
                viewModel.reconcile(with: model.assets)
            }
            .onChange(of: model.assets.map(\.localIdentifier)) { _, _ in
                viewModel.reconcile(with: model.assets)
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
        }
    }

    @ViewBuilder
    private var authorizedContent: some View {
        if viewModel.isScanning && !viewModel.hasCompletedInitialScan {
            ContentUnavailableView {
                Label("Scanning Library", systemImage: "text.viewfinder")
            } description: {
                Text("Analyzing lightweight thumbnails off the main thread to find document-looking images.")
            } actions: {
                VStack(spacing: 12) {
                    ProgressView(value: scanProgressValue) {
                        Text("First Scan In Progress")
                    } currentValueLabel: {
                        Text("\(viewModel.progressCompletedCount) of \(viewModel.progressTotalCount) images")
                    }
                    .frame(width: 240)

                    Text("The scan runs in the background and keeps the UI responsive.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        } else if !viewModel.hasCompletedInitialScan {
            ContentUnavailableView {
                Label("Scan For Documents", systemImage: "doc.text.viewfinder")
            } description: {
                Text("Start a manual scan to find paper-style images with text and screenshots that look document-like.")
            } actions: {
                Button("Scan Library") {
                    viewModel.startScan(using: model.assets)
                }
                .buttonStyle(.glassProminent)
                .disabled(model.assets.isEmpty)
            }
        } else if documentAssets.isEmpty {
            ContentUnavailableView {
                Label("No Document-Looking Images", systemImage: "doc.text.magnifyingglass")
            } description: {
                Text("Try rescanning after library changes. Results favor paper-style images with text and can also include screenshots.")
            } actions: {
                Menu {
                    Button("Scan New Only") {
                        viewModel.startScan(using: model.assets)
                    }
                    .disabled(
                        viewModel.isScanning ||
                        model.assets.isEmpty ||
                        !canScanLibrary ||
                        !viewModel.hasUnscannedAssets(comparedTo: model.assets)
                    )

                    Button("Rescan All") {
                        viewModel.startFullScan(using: model.assets)
                    }
                    .disabled(
                        viewModel.isScanning ||
                        model.assets.isEmpty ||
                        !canScanLibrary
                    )
                } label: {
                    Label("Scan Library", systemImage: "doc.text.viewfinder")
                }
                .buttonStyle(.glassProminent)
            }
        } else {
            GeometryReader { proxy in
                let cellSide = (proxy.size.width / 4).rounded(.down)
                let targetScale = displayScale * 1.5
                let targetSize = CGSize(width: cellSide * targetScale, height: cellSide * targetScale)

                ScrollView {
                    PhotoAssetGridContent(
                        assets: documentAssets,
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
                }
                .overlay(alignment: .bottom) {
                    if viewModel.isScanning {
                        VStack(spacing: 6) {
                            ProgressView(value: scanProgressValue) {
                                Text("Refreshing Library")
                            } currentValueLabel: {
                                Text("\(viewModel.progressCompletedCount) of \(viewModel.progressTotalCount) images")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.bottom, 10)
                    }
                }
            }
        }
    }

    private var canScanLibrary: Bool {
        model.authStatus == .authorized || model.authStatus == .limited
    }

    private var navigationSubtitle: String {
        if viewModel.isScanning {
            return viewModel.hasCompletedInitialScan ? "Refreshing matches" : "Scanning for matches"
        }

        if viewModel.hasCompletedInitialScan {
            let resultCount = documentAssets.count
            if viewModel.hasUnscannedAssets(comparedTo: model.assets) {
                return "\(resultCount) matches • refresh available"
            }
            return "\(resultCount) matches"
        }

        return "\(model.assets.count) photos available"
    }

    private var scanProgressValue: Double {
        guard viewModel.progressTotalCount > 0 else { return 0 }
        return Double(viewModel.progressCompletedCount) / Double(viewModel.progressTotalCount)
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

    @ViewBuilder
    private func selectionBadge(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundColor(isSelected ? .blue : .white)
            .padding(6)
    }
}
