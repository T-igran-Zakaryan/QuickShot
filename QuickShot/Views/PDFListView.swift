import SwiftUI
import UIKit

struct PDFListView: View {
   @State private var service = PDFLibraryService()
   @Environment(\.scenePhase) private var scenePhase
   @Namespace private var namespace
   @State private var selectedPDF : PDFItem?
   
   var body: some View {
      NavigationStack {
         Group {
            if service.pdfItems.isEmpty {
               ContentUnavailableView(
                  "There are no pdfs here",
                  systemImage: "tray.full.fill"
               )
            } else {
               List {
                  ForEach(service.pdfItems) { item in
                     PDFRowView(item: item, service: service, namespace: namespace) {
                        selectedPDF = item
                     }
                     .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                           delete(item)
                        } label: {
                           Label("Delete", systemImage: "trash")
                        }

                        ShareLink(item: item.url) {
                           Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                     }
                  }
               }
               .listStyle(.plain)
            }
         }
         .navigationTitle("Converted Documents")
         .navigationSubtitle("\(service.pdfItems.count) - elements")
         .toolbarTitleDisplayMode(.inlineLarge)
      }
      .fullScreenCover(item: $selectedPDF) { pdf in
         PDFDetailView(item: pdf)
            .navigationTransition(.zoom(sourceID: pdf, in: namespace))
      }
      .onAppear { service.reload() }
      .onChange(of: scenePhase) { oldPhase, newPhase in
         if newPhase == .active {
            service.reload()
         }
      }
   }

   private func delete(_ item: PDFItem) {
      if selectedPDF == item {
         selectedPDF = nil
      }
      service.delete(item)
   }
}


