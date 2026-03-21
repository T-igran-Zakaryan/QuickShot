import Foundation
import VisionKit

@Observable
final class DocumentScannerViewModel {
   var isSaving = false
   var alertMessage: String?

   private let pdfBuilder: ScanPDFBuilding

   init(pdfBuilder: ScanPDFBuilding = ScanPDFBuilder()) {
      self.pdfBuilder = pdfBuilder
   }

   var isScannerSupported: Bool {
      VNDocumentCameraViewController.isSupported
   }

   func startScanIfSupported() -> Bool {
      guard isScannerSupported else {
         alertMessage = "Scanning is not available on this device."
         return false
      }

      return true
   }

   func clearAlert() {
      alertMessage = nil
   }

   func handleScannerError(_ error: Error) {
      alertMessage = error.localizedDescription
   }

   func process(scan: VNDocumentCameraScan, libraryService: PDFLibraryService) {
      guard !isSaving else { return }
      isSaving = true

      pdfBuilder.makePDF(from: scan) { [weak self] result in
         guard let self else { return }

         switch result {
         case .success(let data):
            if libraryService.savePDF(data: data, prefix: "SCAN") == nil {
               alertMessage = "Scan was captured, but saving failed."
            }
         case .failure(let error):
            alertMessage = error.localizedDescription
         }

         isSaving = false
      }
   }
}
