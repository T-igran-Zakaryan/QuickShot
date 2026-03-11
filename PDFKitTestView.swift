import SwiftUI
import Foundation
import PDFKit

struct PDFKitTestView: UIViewRepresentable {
    let url: URL
    @Binding var currentPage: Int
    @Binding var pageCount: Int
    let onScrollStart: (() -> Void)?

    init(
        url: URL,
        currentPage: Binding<Int>,
        pageCount: Binding<Int>,
        onScrollStart: (() -> Void)? = nil
    ) {
        self.url = url
        _currentPage = currentPage
        _pageCount = pageCount
        self.onScrollStart = onScrollStart
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
//        pdfView.usePageViewController(true)
        pdfView.document = PDFDocument(url: url)
       pdfView.autoScales = true
        context.coordinator.attach(to: pdfView)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document?.documentURL != url {
            pdfView.document = PDFDocument(url: url)
            context.coordinator.refreshCounts()

        }
    }

    final class Coordinator: NSObject {
        private let parent: PDFKitTestView
        private weak var pdfView: PDFView?
        private weak var observedPanGesture: UIPanGestureRecognizer?

        init(_ parent: PDFKitTestView) {
            self.parent = parent
        }

        func attach(to pdfView: PDFView) {
            self.pdfView = pdfView
            attachScrollStartListener(to: pdfView)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(pageChanged),
                name: .PDFViewPageChanged,
                object: pdfView
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(documentChanged),
                name: .PDFViewDocumentChanged,
                object: pdfView
            )
            refreshCounts()
        }

        deinit {
            observedPanGesture?.removeTarget(self, action: #selector(panGestureChanged(_:)))
            NotificationCenter.default.removeObserver(self)
        }

        func refreshCounts() {
            updateCounts()
            updateCurrentPage()
        }

        private func attachScrollStartListener(to pdfView: PDFView) {
            guard let scrollView = pdfView.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView else {
                return
            }

            observedPanGesture?.removeTarget(self, action: #selector(panGestureChanged(_:)))
            observedPanGesture = scrollView.panGestureRecognizer
            observedPanGesture?.addTarget(self, action: #selector(panGestureChanged(_:)))
        }

        @objc private func panGestureChanged(_ gesture: UIPanGestureRecognizer) {
            guard gesture.state == .began else {
                return
            }
            parent.onScrollStart?()
        }

        @objc private func pageChanged() {
            updateCurrentPage()
        }

        @objc private func documentChanged() {
            updateCounts()
            updateCurrentPage()
        }

        private func updateCounts() {
            let count = pdfView?.document?.pageCount ?? 0
            DispatchQueue.main.async {
                self.parent.pageCount = count
            }
        }

        private func updateCurrentPage() {
            let index: Int
            if let page = pdfView?.currentPage, let document = pdfView?.document {
                index = document.index(for: page) + 1
            } else {
                index = 0
            }

            DispatchQueue.main.async {
                self.parent.currentPage = index
            }
        }
    }
}
