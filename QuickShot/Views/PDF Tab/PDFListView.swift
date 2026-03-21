import SwiftUI
import UIKit

struct PDFListView: View {
   @State private var service = PDFLibraryService()
   @State private var scannerViewModel = DocumentScannerViewModel()
   @Environment(\.scenePhase) private var scenePhase
   @Namespace private var namespace
   @State private var selectedPDF : PDFItem?
   @State private var isScannerPresented = false
   
   var body: some View {
      NavigationStack {
         Group {
            if service.pdfItems.isEmpty {
               ContentUnavailableView(
                  "There are no PDFs to display here",
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
         .toolbar {
            ToolBarGroup(onAdd: startScannerFlow)
         }
      }
      .overlay {
         if scannerViewModel.isSaving {
            ZStack {
               Color.black.opacity(0.2).ignoresSafeArea()
               ProgressView("Saving scan...")
                  .padding(16)
                  .background(.ultraThinMaterial)
                  .clipShape(RoundedRectangle(cornerRadius: 12))
            }
         }
      }
      .fullScreenCover(item: $selectedPDF) { pdf in
         PDFDetailView(item: pdf)
            .navigationTransition(.zoom(sourceID: pdf, in: namespace))
      }
      .fullScreenCover(isPresented: $isScannerPresented) {
         DocumentScannerView(
            onScan: { scan in
               scannerViewModel.process(scan: scan, libraryService: service)
               isScannerPresented = false
            },
            onCancel: {
               isScannerPresented = false
            },
            onError: { error in
               isScannerPresented = false
               scannerViewModel.handleScannerError(error)
            }
         )
         .ignoresSafeArea()
      }
      .alert(
         "Scanner",
         isPresented: Binding(
            get: { scannerViewModel.alertMessage != nil },
            set: { _ in scannerViewModel.clearAlert() }
         )
      ) {
         Button("OK", role: .cancel) {
            scannerViewModel.clearAlert()
         }
      } message: {
         Text(scannerViewModel.alertMessage ?? "")
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

   private func startScannerFlow() {
      guard scannerViewModel.startScanIfSupported() else { return }
      isScannerPresented = true
   }
}
