//
//  ImageInfoSheetView.swift
//  QuickShot
//
//  Created by Codex on 2025-03-15.
//
import SwiftUI
import Photos

struct ImageInfoSheetView: View {
    let asset: PHAsset

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic info") {
                    InfoRow(title: "Filename", value: filename ?? "Unknown")
                    InfoRow(title: "Dimensions", value: "\(asset.pixelWidth) × \(asset.pixelHeight) px")
                    InfoRow(title: "Aspect ratio", value: aspectRatio)
                    InfoRow(title: "Favorite", value: asset.isFavorite ? "Yes" : "No")
                }

                Section("Dates") {
                    InfoRow(title: "Created", value: formattedDate(asset.creationDate))
                    InfoRow(title: "Modified", value: formattedDate(asset.modificationDate))
                }

                if let location = asset.location {
                    Section("Location") {
                        InfoRow(title: "Latitude", value: String(format: "%.5f", location.coordinate.latitude))
                        InfoRow(title: "Longitude", value: String(format: "%.5f", location.coordinate.longitude))
                    }
                }
            }
            .navigationTitle("Image Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var filename: String? {
        PHAssetResource.assetResources(for: asset).first?.originalFilename
    }

    private var aspectRatio: String {
        let width = max(asset.pixelWidth, 1)
        let height = max(asset.pixelHeight, 1)
        let ratio = Double(width) / Double(height)
        return String(format: "%.2f:1", ratio)
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "Unknown" }
        return AppFormatters.date.string(from: date)
    }
}

private struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}
