import SwiftUI
import Photos

struct DocumentsView: View {
    @State private var model = PhotoLibraryModel()
    @State private var viewModel = DocumentsLibraryViewModel()
    @State private var pdfService = PDFLibraryService()

    private var documentAssets: [PHAsset] {
        viewModel.displayedAssets(from: model.assets)
    }

    var body: some View {
        Group {
            switch model.authStatus {
            case .authorized, .limited:
                authorizedContent
            case .denied, .restricted:
                NavigationStack {
                    ContentUnavailableView(
                        "Photo Access Required",
                        systemImage: "photo.badge.exclamationmark",
                        description: Text("Allow photo library access to scan for document-looking images.")
                    )
                    .navigationTitle("Documents")
                    .navigationSubtitle(navigationSubtitle)
                    .toolbarTitleDisplayMode(.inlineLarge)
                }
            case .notDetermined:
                NavigationStack {
                    ProgressView("Loading Library")
                        .navigationTitle("Documents")
                        .navigationSubtitle(navigationSubtitle)
                        .toolbarTitleDisplayMode(.inlineLarge)
                }
            @unknown default:
                NavigationStack {
                    ProgressView("Loading Library")
                        .navigationTitle("Documents")
                        .navigationSubtitle(navigationSubtitle)
                        .toolbarTitleDisplayMode(.inlineLarge)
                }
            }
        }
        .task {
            await model.requestAuthorization()
            viewModel.reconcile(with: model.assets)
        }
        .onChange(of: model.assets.map(\.localIdentifier)) { _, _ in
            viewModel.reconcile(with: model.assets)
        }
    }

    @ViewBuilder
    private var authorizedContent: some View {
        if viewModel.isScanning && !viewModel.hasCompletedInitialScan {
            NavigationStack {
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
                .navigationTitle("Documents")
                .navigationSubtitle(navigationSubtitle)
                .toolbarTitleDisplayMode(.inlineLarge)
            }
        } else if !viewModel.hasCompletedInitialScan {
            NavigationStack {
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
                .navigationTitle("Documents")
                .navigationSubtitle(navigationSubtitle)
                .toolbarTitleDisplayMode(.inlineLarge)
            }
        } else if documentAssets.isEmpty {
            NavigationStack {
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
                .navigationTitle("Documents")
                .navigationSubtitle(navigationSubtitle)
                .toolbarTitleDisplayMode(.inlineLarge)
            }
        } else {
            SelectableAssetsLibraryView(
                title: "Documents",
                subtitle: navigationSubtitle,
                assets: documentAssets,
                imageManager: model.imageManager,
                autoScrollToBottom: false
            ) { selectedAssets, settings in
                if let data = await model.pdfData(from: selectedAssets, settings: settings) {
                    _ = pdfService.savePDF(data: data)
                }
            } extraToolbar: {
                if viewModel.hasCompletedInitialScan {
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
            } gridBottomOverlay: {
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
}
