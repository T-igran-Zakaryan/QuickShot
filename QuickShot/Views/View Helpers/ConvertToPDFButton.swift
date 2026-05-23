import SwiftUI

struct ConvertToPDFButton: View {
    let selectedCount: Int
    let isConverting: Bool
    let action: () -> Void

    private var isDisabled: Bool {
        selectedCount == 0 || isConverting
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Label("Convert to PDF", systemImage: "doc.badge.plus")
                if selectedCount > 0 {
                    Text("\(selectedCount)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.blue))
                }
            }
        }
        .buttonStyle(.glass)
        .disabled(isDisabled)
    }
}
