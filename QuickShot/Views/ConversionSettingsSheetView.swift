//
//  ConversionSettingsSheet.swift
//  QuickShot
//
//  Created by Тигран Закарян on 15.03.26.
//
import SwiftUI
import PDFKit

struct ConversionSettingsSheetView: View {
   @Binding var pageSize: PDFPageSizeOption
   @Binding var compressionQuality: Double
   @Binding var isConverting: Bool
   let onConvert: () async -> Void

   @Environment(\.dismiss) private var dismiss

   var body: some View {
      NavigationStack {
         Form {
            Section("Size settings") {
               PageSizePickerView(selection: $pageSize)
               Text(description(for: pageSize))
                  .font(.caption)
                  .foregroundStyle(.secondary)
            }

            Section("Compression settings") {
               VStack(spacing: 12) {
                  Slider(value: $compressionQuality, in: 0.4...1.0, step: 0.05)
                  HStack {
                     Text("Smaller file")
                     Spacer()
                     Text("Better quality")
                  }
                  .font(.caption)
                  .foregroundStyle(.secondary)
               }
               Text("Reducing file size don't affect to a reading quality.")
                  .font(.caption)
                  .foregroundStyle(.secondary)
            }

            if isConverting {
               Section {
                  HStack(spacing: 12) {
                     ProgressView()
                     Text("Converting...")
                  }
               }
            }
         }
         .navigationTitle("Conversion Settings")
         .toolbar {
            ToolbarItem(placement: .cancellationAction) {
               Button("Cancel") { dismiss() }
                  .disabled(isConverting)
            }
            ToolbarItem(placement: .confirmationAction) {
               Button("Convert") {
                  Task {
                     await onConvert()
                     dismiss()
                  }
               }
               .disabled(isConverting)
            }
         }
      }
   }

   private func title(for option: PDFPageSizeOption) -> String {
      switch option {
      case .a4:
         return "A4"
      case .keepOriginal:
         return "Keep image size"
      case .fitAll:
         return "Fit all images to a compatible size"
      }
   }

   private func description(for option: PDFPageSizeOption) -> String {
      switch option {
      case .a4:
         return "A4 page size (595 × 842 pt). Images are scaled to fit and centered."
      case .keepOriginal:
         return "Keeps each image at its original pixel size. Pages may vary. This setting is not recommended."
      case .fitAll:
         return "Letter page size (612 × 792 pt). Images are scaled to fit and centered."
      }
   }
}
