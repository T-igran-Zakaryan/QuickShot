//
//  PageSizePickerView.swift
//  QuickShot
//
//  Created by Codex on 2025-03-15.
//
import SwiftUI

struct PageSizePickerView: View {
    @Binding var selection: PDFPageSizeOption

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(PDFPageSizeOption.allCases) { option in
                Button {
                    selection = option
                } label: {
                    Text(title(for: option))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(backgroundColor(for: option))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(borderColor(for: option), lineWidth: borderWidth(for: option))
                        )
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: selection)
            }
        }
    }

    private func title(for option: PDFPageSizeOption) -> String {
        switch option {
        case .a4:
            return "A4"
        case .keepOriginal:
            return "Keep original size"
        case .fitAll:
            return "Fit all images"
        }
    }

    private func backgroundColor(for option: PDFPageSizeOption) -> Color {
        option == selection ? Color.accentColor.opacity(0.14) : Color.clear
    }

    private func borderColor(for option: PDFPageSizeOption) -> Color {
        option == selection ? Color.accentColor : Color.secondary.opacity(0.3)
    }

    private func borderWidth(for option: PDFPageSizeOption) -> CGFloat {
        option == selection ? 2 : 1
    }
}
