import SwiftUI

struct ImagesGridView: View {
    @State private var model = PhotoLibraryModel()
    @State private var pdfService = PDFLibraryService()

    var body: some View {
        SelectableAssetsLibraryView(
            title: "Images",
            subtitle: "\(model.assets.count) - elements",
            assets: model.assets,
            imageManager: model.imageManager,
            autoScrollToBottom: true
        ) { selectedAssets, settings in
            if let data = await model.pdfData(from: selectedAssets, settings: settings) {
                _ = pdfService.savePDF(data: data)
            }
        }
        .task {
            await model.requestAuthorization()
        }
    }
}
