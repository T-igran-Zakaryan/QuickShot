import SwiftUI

struct PDFDetailView: View {
   @Environment(\.dismiss) private var dismiss
   @State private var isSharing = false
   @State private var currentPage = 0
   @State private var pageCount = 0
   @State private var showPageHUD = false
   @State private var hidePageHUDWorkItem: DispatchWorkItem?


   let item: PDFItem

   var body: some View {
      NavigationStack {
         //      PDFKitView(
         //         url: item.url,
         //         currentPage: $currentPage,
         //         pageCount: $pageCount,
         //         onScrollStart: showPageIndicator
         //      )
         PDFKitTestView(
            url: item.url,
            currentPage: $currentPage,
            pageCount: $pageCount,
            onScrollStart: showPageIndicator
         )
         .truncatedNavigationTitle(item.displayName.truncatedMiddle(charLimit: 10))
         .navigationBarTitleDisplayMode(.inline)
         .ignoresSafeArea(.all, edges: .all)

         .overlay(alignment: .bottomTrailing) {
            if pageCount > 1 {
               Text("\(currentPage)/\(pageCount)")
                  .font(.callout.weight(.semibold))
                  .padding(.horizontal, 14)
                  .padding(.vertical, 8)
                  .glassEffect()
                  .clipShape(Capsule())
                  .padding(.trailing, 12)
                  .padding(.bottom, 12)
                  .opacity(showPageHUD ? 1 : 0)
                  .animation(.easeInOut(duration: 0.25), value: showPageHUD)
            }
         }

         .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
               ShareLink(item: item.url) {
                  Image(systemName: "square.and.arrow.up.fill")
               }
            }
            ToolbarItem(placement: .topBarLeading) {
               Button { dismiss() } label: {
                  Image(systemName: "chevron.backward")
               }
            }

            ToolbarTitleMenu {
               Button {
                  isSharing = true
               } label: {
                  Label("Share", systemImage: "square.and.arrow.up.fill")
                  Text("\(formattedSize(item.fileSize)) - " + item.displayName.truncatedMiddle(charLimit: 6))
               }
            }
         }
         .sheet(isPresented: $isSharing) {
            ActivityView(items: [item.url])
            //               .presentationDetents([.height(340), .large])
               .presentationDetents([.large])
               .presentationDragIndicator(.visible)
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
}

struct ActivityView: UIViewControllerRepresentable {
   let items: [Any]

   func makeUIViewController(context: Context) -> UIActivityViewController {
      UIActivityViewController(activityItems: items, applicationActivities: nil)
   }

   func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
