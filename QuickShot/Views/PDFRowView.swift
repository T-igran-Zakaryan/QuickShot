//
//  PDFRowView.swift
//  Images
//
//  Created by Тигран Закарян on 06.03.26.
//

import SwiftUI

struct PDFRowView: View {
   let item: PDFItem
   let service: PDFLibraryService
   let namespace: Namespace.ID
   let onSelect: () -> Void
   
   @State private var thumbnail: UIImage?
   
   var body: some View {
      HStack(spacing: 12) {
         Group {
            if let thumbnail {
               Image(uiImage: thumbnail)
                  .resizable()
                  .scaledToFit()
                  .clipShape(RoundedRectangle(cornerRadius: 4))
                  .overlay(
                     RoundedRectangle(cornerRadius: 4)
                        .stroke(
                           LinearGradient(
                              colors: [
                                 Color(white: 0.9),
                                 Color(white: 0.7),
                                 Color(white: 0.85)
                              ],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing
                           ),
                           lineWidth: 0.5
                        )
                  )
                  .matchedTransitionSource(id: item, in: namespace)
            } else {
               RoundedRectangle(cornerRadius: 6)
                  .fill(Color.secondary.opacity(0.15))
                  .overlay(
                     Image(systemName: "doc.richtext")
                        .font(.body)
                        .foregroundStyle(.secondary)
                  )
            }
         }
         .frame(width: 50, height: 72)

         VStack(alignment: .leading, spacing: 4) {
            Text(item.displayName)
               .font(.body)
               .lineLimit(1)
            
            Text(AppFormatters.date.string(from: item.createdAt))
               .font(.footnote)
               .foregroundStyle(.secondary)
            
            Text(AppFormatters.fileSize.string(fromByteCount: item.fileSize))
               .font(.caption2)
               .foregroundStyle(.secondary)
         }
      }
     
      .onTapGesture(perform: onSelect)
      .task(id: item.url) {
         thumbnail = await service.thumbnail(for: item.url)
      }
   }
}
