import SwiftUI
import Photos

struct DocumentsView: View {
    @Environment(\.displayScale) private var displayScale
    @State private var model = PhotoLibraryModel()
    @State private var viewModel = DocumentsLibraryViewModel()
    @State private var selectedAsset: SelectedAsset?
    @State private var isZoomedInFullScreen = false
    @State private var imageHeight: CGFloat = 80
    @Namespace private var namespace

    private let gridItemCount = 5

    private var documentAssets: [PHAsset] {
        viewModel.displayedAssets(from: model.assets)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button(scanButtonTitle, systemImage: scanButtonSystemImage) {
                        viewModel.startScan(using: model.assets)
                    }
                    .disabled(viewModel.isScanning || model.assets.isEmpty || !canScanLibrary)
                }
            }
            .task {
                await model.requestAuthorization()
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
                ProgressView(value: scanProgressValue)
                    .frame(maxWidth: 220)
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
            ContentUnavailableView(
                "No Document-Looking Images",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Try rescanning after library changes. Results favor paper-style images with text and can also include screenshots.")
            )
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
                        onLongPress: nil,
                        imageHeight: $imageHeight
                    ) { _ in
                        EmptyView()
                    }
                }
                .overlay(alignment: .bottom) {
                    if viewModel.isScanning {
                        ProgressView(value: scanProgressValue) {
                            Text("Rescanning Library")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.regularMaterial, in: Capsule())
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
            return "\(viewModel.progressCompletedCount) / \(max(viewModel.progressTotalCount, 1)) scanned"
        }

        if viewModel.hasCompletedInitialScan {
            let resultCount = documentAssets.count
            if viewModel.hasLibraryChanges(comparedTo: model.assets) {
                return "\(resultCount) matches • rescan recommended"
            }
            return "\(resultCount) matches"
        }

        return "\(model.assets.count) photos available"
    }

    private var scanProgressValue: Double {
        guard viewModel.progressTotalCount > 0 else { return 0 }
        return Double(viewModel.progressCompletedCount) / Double(viewModel.progressTotalCount)
    }

    private var scanButtonTitle: String {
        viewModel.hasCompletedInitialScan ? "Rescan" : "Scan"
    }

    private var scanButtonSystemImage: String {
        viewModel.hasCompletedInitialScan ? "arrow.clockwise" : "text.viewfinder"
    }

    @MainActor
    private func handleTap(on asset: PHAsset) {
        selectedAsset = SelectedAsset(asset: asset)
    }
}
