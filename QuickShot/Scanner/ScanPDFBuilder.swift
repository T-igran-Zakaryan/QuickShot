import Foundation
import PDFKit
import UIKit
import VisionKit

protocol ScanPDFBuilding {
   func makePDF(from scan: VNDocumentCameraScan, completion: @escaping (Result<Data, ScanPDFBuilderError>) -> Void)
}

enum ScanPDFBuilderError: LocalizedError {
   case emptyScan
   case generationFailed

   var errorDescription: String? {
      switch self {
      case .emptyScan:
         return "No pages were scanned."
      case .generationFailed:
         return "Could not generate a PDF from scanned pages."
      }
   }
}

final class ScanPDFBuilder: ScanPDFBuilding {
   private let queue = DispatchQueue(label: "QuickShot.scan.pdf.builder", qos: .userInitiated)
   private let pageRect = CGRect(origin: .zero, size: CGSize(width: 595.2, height: 841.8)) // A4 at 72 dpi
   private let maxImageDimension: CGFloat = 2_500

   func makePDF(from scan: VNDocumentCameraScan, completion: @escaping (Result<Data, ScanPDFBuilderError>) -> Void) {
      queue.async { [pageRect, maxImageDimension] in
         let result = Self.buildPDF(
            from: scan,
            pageRect: pageRect,
            maxImageDimension: maxImageDimension
         )

         DispatchQueue.main.async {
            completion(result)
         }
      }
   }

   private static func buildPDF(
      from scan: VNDocumentCameraScan,
      pageRect: CGRect,
      maxImageDimension: CGFloat
   ) -> Result<Data, ScanPDFBuilderError> {
      guard scan.pageCount > 0 else {
         return .failure(.emptyScan)
      }

      let document = PDFDocument()

      let pageSize = pageRect.size

      for index in 0..<scan.pageCount {
         autoreleasepool {
            let rawImage = scan.imageOfPage(at: index)
            let normalized = rawImage.normalizedOrientation()
            let prepared = normalized.downsampled(maxDimension: maxImageDimension)

            guard prepared.size.width > 0, prepared.size.height > 0 else { return }
            guard let pageImage = prepared.renderedOnCanvas(pageSize: pageSize) else { return }
            guard let page = PDFPage(image: pageImage) else { return }

            document.insert(page, at: document.pageCount)
         }
      }

      guard document.pageCount > 0 else {
         return .failure(.generationFailed)
      }

      guard let data = document.dataRepresentation() else {
         return .failure(.generationFailed)
      }

      return .success(data)
   }
}

private extension UIImage {
   func normalizedOrientation() -> UIImage {
      guard imageOrientation != .up else { return self }

      let renderer = UIGraphicsImageRenderer(size: size)
      return renderer.image { _ in
         draw(in: CGRect(origin: .zero, size: size))
      }
   }

   func downsampled(maxDimension: CGFloat) -> UIImage {
      let maxCurrentDimension = max(size.width, size.height)
      guard maxCurrentDimension > maxDimension else { return self }

      let scale = maxDimension / maxCurrentDimension
      let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

      let format = UIGraphicsImageRendererFormat.default()
      format.scale = 1
      format.opaque = true

      let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
      return renderer.image { _ in
         draw(in: CGRect(origin: .zero, size: targetSize))
      }
   }

   func renderedOnCanvas(pageSize: CGSize) -> UIImage? {
      guard pageSize.width > 0, pageSize.height > 0 else { return nil }
      guard size.width > 0, size.height > 0 else { return nil }

      let renderer = UIGraphicsImageRenderer(size: pageSize)
      return renderer.image { _ in
         UIColor.white.setFill()
         UIRectFill(CGRect(origin: .zero, size: pageSize))

         let scale = min(pageSize.width / size.width, pageSize.height / size.height)
         let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
         let origin = CGPoint(
            x: (pageSize.width - targetSize.width) / 2.0,
            y: (pageSize.height - targetSize.height) / 2.0
         )
         draw(in: CGRect(origin: origin, size: targetSize))
      }
   }
}
