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
}


