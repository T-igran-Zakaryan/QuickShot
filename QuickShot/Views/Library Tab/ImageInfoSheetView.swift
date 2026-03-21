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
    @State private var placeName: String?
   
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
   
   private var locationKey: String? {
      guard let location = asset.location else { return nil }
      return "\(location.coordinate.latitude),\(location.coordinate.longitude)"
   }

    var body: some View {
        NavigationStack {
            Form {
                VStack(alignment: .leading, spacing: 6) {
                    InfoRow(title: "Filename", value: filename ?? "Unknown")
                    InfoRow(title: "File size", value: fileSize ?? "Unknown")
                    InfoRow(title: "Dimensions", value: "\(asset.pixelWidth) × \(asset.pixelHeight) px")
                    InfoRow(title: "Created", value: formattedDate(asset.creationDate))
                    InfoRow(title: "Modified", value: formattedDate(asset.modificationDate))
                   
                    if let location = asset.location {
                        InfoRow(title: "Place", value: placeName ?? "Unknown") {
                            Map(initialPosition: .region(region(for: location))) {
                                Marker(placeName ?? "Photo location", coordinate: location.coordinate)
                            }
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
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
        .task(id: locationKey) {
            await loadPlaceName()
        }
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

    @MainActor
    private func loadPlaceName() async {
        guard let location = asset.location else {
            placeName = nil
            return
        }

        guard let request = MKReverseGeocodingRequest(location: location) else {
            placeName = nil
            return
        }

        do {
            let mapItems = try await request.mapItems
            placeName = formatMapItem(mapItems.first)
        } catch {
            placeName = nil
        }
    }

    private func formatMapItem(_ mapItem: MKMapItem?) -> String? {
        guard let mapItem else { return nil }

        if let representations = mapItem.addressRepresentations {
            if let cityWithContext = representations.cityWithContext(.automatic) {
                return cityWithContext
            }
            if let cityName = representations.cityName, let regionName = representations.regionName {
                return "\(cityName), \(regionName)"
            }
            if let fullAddress = representations.fullAddress(includingRegion: true, singleLine: true) {
                return fullAddress
            }
        }

        if let shortAddress = mapItem.address?.shortAddress {
            return shortAddress
        }

        return mapItem.address?.fullAddress
    }
}

private struct InfoRow<Detail: View>: View {
    let title: String
    let value: String
    @ViewBuilder let detail: () -> Detail

    init(
        title: String,
        value: String,
        @ViewBuilder detail: @escaping () -> Detail = { EmptyView() }
    ) {
        self.title = title
        self.value = value
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.footnote)
                    .multilineTextAlignment(.trailing)
            }

            detail()

            Divider()
        }
    }
}
