

import Foundation
import PDFKit
import UIKit

@Observable
final class PDFLibraryService {
   var pdfItems: [PDFItem] = []

   private let thumbnailCache = NSCache<NSURL, UIImage>()

   private var documentsURL: URL {
      FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
   }

   func reload() {
      let keys: Set<URLResourceKey> = [.contentModificationDateKey, .creationDateKey, .fileSizeKey, .nameKey]
      let urls = (try? FileManager.default.contentsOfDirectory(
         at: documentsURL,
         includingPropertiesForKeys: Array(keys),
         options: [.skipsHiddenFiles]
      )) ?? []

      let items = urls
         .filter { $0.pathExtension.lowercased() == "pdf" }
         .compactMap { url -> PDFItem? in
            let values = try? url.resourceValues(forKeys: keys)
            let createdAt = values?.creationDate ?? values?.contentModificationDate ?? Date.distantPast
            let fileSize = Int64(values?.fileSize ?? 0)
            let displayName = values?.name ?? url.lastPathComponent
            return PDFItem(
               url: url,
               displayName: displayName,
               createdAt: createdAt,
               fileSize: fileSize
            )
         }
         .sorted { $0.createdAt > $1.createdAt }

      pdfItems = items
   }

   func savePDF(data: Data, prefix: String = "I2P") -> URL? {
      let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
      let fileName = "\(prefix)_\(timestamp).pdf"
      let destinationURL = documentsURL.appendingPathComponent(fileName)

      do {
         try data.write(to: destinationURL, options: [.atomic])
         reload()
         return destinationURL
      } catch {
         print("Error saving PDF: \(error.localizedDescription)")
         return nil
      }
   }

   func delete(_ items: [PDFItem]) {
      for item in items {
         thumbnailCache.removeObject(forKey: item.url as NSURL)
         try? FileManager.default.removeItem(at: item.url)
      }
      reload()
   }

   func delete(_ item: PDFItem) {
      delete([item])
   }

   func thumbnail(for url: URL) async -> UIImage? {
      if let cached = thumbnailCache.object(forKey: url as NSURL) {
         return cached
      }

      let image: UIImage? = await Task.detached(priority: .utility) { () -> UIImage? in
         autoreleasepool {
            guard let document = PDFDocument(url: url),
                  let page = document.page(at: 0) else {
               return nil
            }

            // Render a crisp thumbnail that preserves page orientation without going full resolution.
            let pageSize = page.bounds(for: .cropBox).size
            let maxLongEdge: CGFloat = 240         // points; keeps thumbs sharp but lightweight
            let aspect = pageSize.width / pageSize.height

            let targetSizePoints: CGSize
            if aspect >= 1 {
               targetSizePoints = CGSize(width: maxLongEdge, height: maxLongEdge / aspect)
            } else {
               targetSizePoints = CGSize(width: maxLongEdge * aspect, height: maxLongEdge)
            }

            // Multiply by screen scale so the displayed image isn't pixelated.
            let scale = UIScreen.main.scale
            let targetSize = CGSize(
               width: targetSizePoints.width * scale,
               height: targetSizePoints.height * scale
            )

            return page.thumbnail(of: targetSize, for: .cropBox)
         }
      }.value

      if let image {
         thumbnailCache.setObject(image, forKey: url as NSURL)
      }

      return image
   }
}
