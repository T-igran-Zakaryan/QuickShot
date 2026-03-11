//
//  WebPDFView.swift
//  Images
//
//  Created by Тигран Закарян on 08.03.26.
//

import SwiftUI
import WebKit

struct WebPDFView: View {
   let item: PDFItem
   @Environment(\.dismiss) private var dismiss

   var body: some View {
      NavigationStack {
         WebView(url: item.url)
            .toolbar {
               ToolbarItem(placement: .principal) {
                  Text(item.displayName)
                     .padding(6)
                     .glassEffect()
               }

               ToolbarItem(placement: .topBarTrailing) {
                  Button {
                     dismiss()
                  } label: {
                     Image(systemName: "xmark")
                  }
               }
            }
//            .navigationTitle(item.displayName)
//            .navigationBarTitleDisplayMode(.inline)
      }
   }
}
