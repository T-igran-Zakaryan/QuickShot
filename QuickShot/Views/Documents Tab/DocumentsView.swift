import SwiftUI

struct DocumentsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No Documents Yet",
                systemImage: "doc.text.viewfinder",
                description: Text("Document-looking images from your library will appear here once this feature is implemented.")
            )
            .navigationTitle("Documents")
        }
    }
}
