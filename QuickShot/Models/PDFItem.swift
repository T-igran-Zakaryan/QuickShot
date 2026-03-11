//
//  PDFItem.swift
//  Image to PDF
//
//  Created by Тигран Закарян on 20.02.26.
//
import Foundation

struct PDFItem: Identifiable, Hashable {
    let url: URL
    let displayName: String
    let createdAt: Date
    let fileSize: Int64

    var id: URL { url }
}
