import SwiftUI
import Foundation
import PDFKit

struct PDFKitView: UIViewRepresentable {
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
        pdfView.autoScales = false
//        pdfView.usePageViewController(true)
        pdfView.document = PDFDocument(url: url)
        context.coordinator.attach(to: pdfView)
        context.coordinator.applyFitScale()
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document?.documentURL != url {
            pdfView.document = PDFDocument(url: url)
            context.coordinator.refreshCounts()
            context.coordinator.applyFitScale()
        }
    }

    final class Coordinator: NSObject {
        private let parent: PDFKitView
        private weak var pdfView: PDFView?
        private weak var observedPanGesture: UIPanGestureRecognizer?

        init(_ parent: PDFKitView) {
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

        func applyFitScale() {
            DispatchQueue.main.async { [weak self] in
                self?.applyInitialLayoutPass(scheduleRetry: true)
            }
        }

        private func applyInitialLayoutPass(scheduleRetry: Bool) {
            guard let pdfView = pdfView, let document = pdfView.document else {
                return
            }

            pdfView.layoutIfNeeded()

            let fitScale = widthFitScale(for: document, in: pdfView) ?? pdfView.scaleFactorForSizeToFit
            guard fitScale > 0 else {
                return
            }

            pdfView.minScaleFactor = fitScale
            pdfView.maxScaleFactor = max(fitScale * 4.0, fitScale)
            pdfView.scaleFactor = fitScale
            goToTopOfFirstPage(in: pdfView, document: document)

            if scheduleRetry {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.applyInitialLayoutPass(scheduleRetry: false)
                }
            }
        }

        private func widthFitScale(for document: PDFDocument, in pdfView: PDFView) -> CGFloat? {
            let availableWidth = pdfView.bounds.width - pdfView.safeAreaInsets.left - pdfView.safeAreaInsets.right
            guard availableWidth > 0 else {
                return nil
            }

            var widestPageWidth: CGFloat = 0
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else {
                    continue
                }
                widestPageWidth = max(widestPageWidth, page.bounds(for: pdfView.displayBox).width)
            }

            guard widestPageWidth > 0 else {
                return nil
            }
            return availableWidth / widestPageWidth
        }

        private func goToTopOfFirstPage(in pdfView: PDFView, document: PDFDocument) {
            guard let firstPage = document.page(at: 0) else {
                return
            }

            let bounds = firstPage.bounds(for: pdfView.displayBox)
            let destination = PDFDestination(page: firstPage, at: CGPoint(x: bounds.minX, y: bounds.maxY))
            pdfView.go(to: destination)
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


//import SwiftUI
//import Foundation
//import PDFKit
//
//struct PDFKitView: UIViewRepresentable {
//   let url: URL
//   @Binding var currentPage: Int
//   @Binding var pageCount: Int
//   
//   func makeCoordinator() -> Coordinator {
//      Coordinator(self)
//   }
//   
//   func makeUIView(context: Context) -> PDFView {
//      let pdfView = PDFView()
//
//      pdfView.document = PDFDocument(url: url)
//      pdfView.autoScales = true
//      pdfView.displayMode = .singlePageContinuous
//      pdfView.displayDirection = .vertical
//      pdfView.pageBreakMargins = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
//      if let scrollView = pdfView.subviews.first(where: { $0 is UIScrollView}) as? UIScrollView { scrollView.backgroundColor = UIColor.white }
//      
//      context.coordinator.attach(to: pdfView)
//      return pdfView
//   }
//   
//   func updateUIView(_ pdfView: PDFView, context: Context) {
//      if pdfView.document?.documentURL != url {
//         pdfView.document = PDFDocument(url: url)
//         context.coordinator.refreshCounts()
//      }
//   }
//   
//   final class Coordinator: NSObject {
//      private let parent: PDFKitView
//      private weak var pdfView: PDFView?
//      
//      init(_ parent: PDFKitView) {
//         self.parent = parent
//      }
//      
//      func attach(to pdfView: PDFView) {
//         self.pdfView = pdfView
//         NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(pageChanged),
//            name: .PDFViewPageChanged,
//            object: pdfView
//         )
//         NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(documentChanged),
//            name: .PDFViewDocumentChanged,
//            object: pdfView
//         )
//         refreshCounts()
//      }
//      
//      deinit {
//         NotificationCenter.default.removeObserver(self)
//      }
//      
//      func refreshCounts() {
//         updateCounts()
//         updateCurrentPage()
//      }
//      
//      @objc private func pageChanged() {
//         updateCurrentPage()
//      }
//      
//      @objc private func documentChanged() {
//         updateCounts()
//         updateCurrentPage()
//      }
//      
//      private func updateCounts() {
//         let count = pdfView?.document?.pageCount ?? 0
//         DispatchQueue.main.async {
//            self.parent.pageCount = count
//         }
//      }
//      
//      private func updateCurrentPage() {
//         let index: Int
//         if let page = pdfView?.currentPage, let document = pdfView?.document {
//            index = document.index(for: page) + 1
//         } else {
//            index = 0
//         }
//         
//         DispatchQueue.main.async {
//            self.parent.currentPage = index
//         }
//      }
//   }
//}



/*
 import SwiftUI
 import Foundation
 import PDFKit
 
 struct PDFKitView: UIViewRepresentable {
 let url: URL
 @Binding var currentPage: Int
 @Binding var pageCount: Int
 
 func makeCoordinator() -> Coordinator {
 Coordinator(self)
 }
 
 func makeUIView(context: Context) -> PDFView {
 let pdfView = PDFView()
 
 pdfView.document = PDFDocument(url: url)
 pdfView.autoScales = true
 pdfView.displayMode = .singlePageContinuous
 pdfView.displayDirection = .vertical
 pdfView.pageBreakMargins = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
 if let scrollView = pdfView.subviews.first(where: { $0 is UIScrollView}) as? UIScrollView { scrollView.backgroundColor = UIColor.white }
 
 context.coordinator.attach(to: pdfView)
 context.coordinator.applyInitialScale()
 return pdfView
 }
 
 func updateUIView(_ pdfView: PDFView, context: Context) {
 if pdfView.document?.documentURL != url {
 pdfView.document = PDFDocument(url: url)
 context.coordinator.refreshCounts()
 context.coordinator.resetInitialScale()
 context.coordinator.applyInitialScale()
 }
 }
 
 final class Coordinator: NSObject {
 private let parent: PDFKitView
 private weak var pdfView: PDFView?
 private var didApplyInitialScale = false
 
 init(_ parent: PDFKitView) {
 self.parent = parent
 }
 
 func attach(to pdfView: PDFView) {
 self.pdfView = pdfView
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
 NotificationCenter.default.removeObserver(self)
 }
 
 func refreshCounts() {
 updateCounts()
 updateCurrentPage()
 }
 
 func resetInitialScale() {
 didApplyInitialScale = false
 }
 
 func applyInitialScale() {
 guard !didApplyInitialScale else { return }
 DispatchQueue.main.async { [weak self] in
 guard let pdfView = self?.pdfView else {
 return
 }
 let fitScale = pdfView.scaleFactorForSizeToFit
 if fitScale > 0 {
 pdfView.minScaleFactor = fitScale * 0.75
 pdfView.maxScaleFactor = max(fitScale * 4.0, fitScale)
 pdfView.scaleFactor = fitScale * 0.9
 self?.didApplyInitialScale = true
 }
 }
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

 
 */
