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
               Picker("Page size", selection: $pageSize) {
                  ForEach(PDFPageSizeOption.allCases) { option in
                     Text(title(for: option)).tag(option)
                  }
               }
               .pickerStyle(.inline)
            }

            Section("Compression") {
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
               Text("Reduce file size while keeping readability.")
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
         return "Keep original size (not recommended)"
      case .fitAll:
         return "Fit all images to a compatible size"
      }
   }
}
