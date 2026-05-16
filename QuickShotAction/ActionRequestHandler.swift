//
//  ActionRequestHandler.swift
//  QuickShotAction
//
//  Created by Тигран Закарян on 03.05.26.
//

import UIKit
import UniformTypeIdentifiers

final class ActionRequestHandler: NSObject, NSExtensionRequestHandling {
    private var extensionContext: NSExtensionContext?

    func beginRequest(with context: NSExtensionContext) {
        extensionContext = context

        for item in context.inputItems.compactMap({ $0 as? NSExtensionItem }) {
            guard let attachments = item.attachments else { continue }

            for itemProvider in attachments where itemProvider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) {
                itemProvider.loadItem(forTypeIdentifier: UTType.propertyList.identifier, options: nil) { [weak self] item, _ in
                    guard let self else { return }

                    let dictionary = item as? [String: Any]
                    let preprocessing = dictionary?[NSExtensionJavaScriptPreprocessingResultsKey] as? [String: Any] ?? [:]
                    self.handlePreprocessingResults(preprocessing)
                }
                return
            }
        }

        complete(with: nil)
    }

    private func handlePreprocessingResults(_ results: [String: Any]) {
        let html = (results["html"] as? String) ?? ""
        let title = sanitizedFileName((results["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines))
        let urlString = results["url"] as? String

        let content = buildPrintableHTML(from: html, urlString: urlString)
        guard let pdfData = makePDFData(fromHTML: content) else {
            complete(with: nil)
            return
        }

        let fileName = (title?.isEmpty == false ? title! : "QuickShot") + ".pdf"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try pdfData.write(to: fileURL, options: .atomic)
            complete(with: fileURL)
        } catch {
            complete(with: nil)
        }
    }

    private func buildPrintableHTML(from html: String, urlString: String?) -> String {
        guard !html.isEmpty else {
            let escapedURL = (urlString ?? "").replacingOccurrences(of: "&", with: "&amp;")
            return "<html><body><p>\(escapedURL)</p></body></html>"
        }

        guard let urlString, !urlString.isEmpty else { return html }
        guard !html.contains("<base ") else { return html }

        if let range = html.range(of: "<head>", options: .caseInsensitive) {
            let baseTag = "<base href=\"\(urlString)\">"
            return html.replacingCharacters(in: range, with: "<head>\(baseTag)")
        }

        return html
    }

    private func makePDFData(fromHTML html: String) -> Data? {
        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        let renderer = A4PrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, renderer.paperRect, nil)

        for pageIndex in 0 ..< renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: pageIndex, in: UIGraphicsGetPDFContextBounds())
        }

        UIGraphicsEndPDFContext()
        return data as Data
    }

    private func sanitizedFileName(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }

        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let clean = value.components(separatedBy: invalid).joined(separator: "-")
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func complete(with pdfURL: URL?) {
        defer { extensionContext = nil }

        guard let extensionContext else { return }

        if let pdfURL {
            let itemProvider = NSItemProvider(contentsOf: pdfURL)
            let outputItem = NSExtensionItem()
            outputItem.attachments = itemProvider.map { [$0] }
            extensionContext.completeRequest(returningItems: [outputItem], completionHandler: nil)
            return
        }

        extensionContext.completeRequest(returningItems: [], completionHandler: nil)
    }
}

private final class A4PrintPageRenderer: UIPrintPageRenderer {
    private static let a4Size = CGSize(width: 595.2, height: 841.8)

    override init() {
        super.init()

        let paper = CGRect(origin: .zero, size: Self.a4Size)
        let printable = paper.insetBy(dx: 20, dy: 20)

        setValue(NSValue(cgRect: paper), forKey: "paperRect")
        setValue(NSValue(cgRect: printable), forKey: "printableRect")
    }
}
