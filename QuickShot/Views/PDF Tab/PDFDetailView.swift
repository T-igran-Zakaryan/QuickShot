import SwiftUI
import PDFKit

struct PDFDetailView: View {
   @Environment(\.dismiss) private var dismiss
   @State private var isSharing = false
   @State private var currentPage = 0
   @State private var pageCount = 0
   @State private var showPageHUD = false
   @State private var hidePageHUDWorkItem: DispatchWorkItem?
   @State private var thumbnailImage = UIImage(systemName: "doc.richtext") ?? UIImage()


   let item: PDFItem

   private var documentPreview: SharePreview<Image, Never> {
      SharePreview(item.displayName.truncatedMiddle(charLimit: 6), image: Image(uiImage: thumbnailImage))
   }

   var body: some View {
      NavigationStack {
         PDFKitTestView(
            url: item.url,
            currentPage: $currentPage,
            pageCount: $pageCount,
            onScrollStart: showPageIndicator
         )
         .truncatedNavigationTitle(item.displayName.truncatedMiddle(charLimit: 10))
         .navigationBarTitleDisplayMode(.inline)
         .ignoresSafeArea(.all, edges: .all)
         .navigationDocument(item.url, preview: documentPreview)
//         .overlay(alignment: .bottomTrailing) {
//            if pageCount > 1 {
//               Text("\(currentPage)/\(pageCount)")
//                  .font(.callout.weight(.semibold))
//                  .padding(.horizontal, 14)
//                  .padding(.vertical, 8)
//                  .glassEffect()
//                  .clipShape(Capsule())
//                  .padding(.trailing, 12)
//                  .padding(.bottom, 12)
//                  .opacity(showPageHUD ? 1 : 0)
//                  .animation(.easeInOut(duration: 0.25), value: showPageHUD)
//            }
//         }

         .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
               if pageCount > 1 {
                  Text("\(currentPage)/\(pageCount)")
                     .font(.callout.weight(.semibold))
               }
            }
            ToolbarItem(placement: .topBarLeading) {
               Button { dismiss() } label: {
                  Image(systemName: "chevron.backward")
               }
            }
         }
         .task(id: item.url) {
            loadThumbnail()
         }
      }
   }

   private func formattedSize(_ bytes: Int64) -> String {
      AppFormatters.fileSize.string(fromByteCount: bytes)
   }

   private func showPageIndicator() {
      hidePageHUDWorkItem?.cancel()
      withAnimation(.easeInOut(duration: 0.25)) {
         showPageHUD = true
      }

      let workItem = DispatchWorkItem {
         withAnimation(.easeInOut(duration: 0.25)) {
            showPageHUD = false
         }
      }
      hidePageHUDWorkItem = workItem
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: workItem)
   }

   @MainActor
   private func loadThumbnail() {
      guard
         let document = PDFDocument(url: item.url),
         let firstPage = document.page(at: 0)
      else {
         thumbnailImage = UIImage(systemName: "doc.richtext") ?? UIImage()
         return
      }

      let pageBounds = firstPage.bounds(for: .mediaBox)
      let aspectRatio = max(pageBounds.height / max(pageBounds.width, 1), 1)
      let thumbnailSize = CGSize(width: 240, height: 240 * aspectRatio)
      thumbnailImage = firstPage.thumbnail(of: thumbnailSize, for: .mediaBox)
   }
}
