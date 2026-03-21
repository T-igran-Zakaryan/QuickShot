//
//  SelectedAsset.swift
//  QuickShot
//
//  Created by Тигран Закарян on 21.03.26.
//
import SwiftUI
import Photos

/// Wrapper to give PHAsset identity without retroactive conformance.
struct SelectedAsset: Identifiable {
   let asset: PHAsset
   var id: String { asset.localIdentifier }
}
