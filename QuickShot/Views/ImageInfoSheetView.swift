//
//  ImageInfoSheetView.swift
//  QuickShot
//
//  Created by Codex on 2025-03-15.
//
import SwiftUI
import Photos
import MapKit

struct ImageInfoSheetView: View {
    let asset: PHAsset

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                VStack(alignment: .leading, spacing: 6) {
                    
                    InfoRow(title: "Filename", value: filename ?? "Unknown")
                    InfoRow(title: "File size", value: fileSize ?? "Unknown")
                    InfoRow(title: "Dimensions", value: "\(asset.pixelWidth) × \(asset.pixelHeight) px")
                    InfoRow(title: "Aspect ratio", value: aspectRatio)
                    InfoRow(title: "Favorite", value: asset.isFavorite ? "Yes" : "No")
                    InfoRow(title: "Created", value: formattedDate(asset.creationDate))
                    InfoRow(title: "Modified", value: formattedDate(asset.modificationDate))
                    if let location = asset.location {
                        Map(initialPosition: .region(region(for: location))) {
                            Marker("Photo location", coordinate: location.coordinate)
                        }
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .navigationTitle("Image Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                   Button{
                      dismiss()
                   } label: {
                      Image(systemName: "xmark")
                   }
                }
            }
        }
    }

    private var filename: String? {
        PHAssetResource.assetResources(for: asset).first?.originalFilename
    }

    private var fileSize: String? {
        guard let resource = PHAssetResource.assetResources(for: asset).first else { return nil }
        if let bytes = resource.value(forKey: "fileSize") as? Int64 {
            return AppFormatters.fileSize.string(fromByteCount: bytes)
        }
        return nil
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

    private func region(for location: CLLocation) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
}

private struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.footnote)
                .multilineTextAlignment(.trailing)
        }
       Divider()
    }
}
