   /// Wrapper to give PHAsset identity without retroactive conformance.
struct SelectedAsset: Identifiable {
   let asset: PHAsset
   var id: String { asset.localIdentifier }
}