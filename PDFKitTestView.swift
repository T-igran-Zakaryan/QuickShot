import SwiftUI
import Foundation
import PDFKit

struct PDFKitTestView: UIViewRepresentable {
   let url: URL
   let scrollDownOffset: CGFloat
   @Binding var currentPage: Int
   @Binding var pageCount: Int
   let onScrollStart: (() -> Void)?


   init(url: URL, scrollDownOffset: CGFloat = -40, currentPage: Binding<Int>, pageCount: Binding<Int>, onScrollStart: (() -> Void)? = nil) {
      self.url = url
      self.scrollDownOffset = scrollDownOffset
      _currentPage = currentPage
      _pageCount = pageCount
      self.onScrollStart = onScrollStart
   }

   func makeCoordinator() -> Coordinator {
      Coordinator(self)
   }

   func makeUIView(context: Context) -> PDFView {
      let pdfView = PDFView()
      pdfView.autoScales = true
      pdfView.displayMode = .singlePageContinuous
      pdfView.displayDirection = .vertical
      pdfView.displaysPageBreaks = true
      pdfView.backgroundColor = .clear
      pdfView.document = PDFDocument(url: url)
      context.coordinator.attach(to: pdfView)

      return pdfView
   }

   func updateUIView(_ uiView: PDFView, context: Context) {
      let documentChanged = uiView.document?.documentURL != url
      let boundsChanged = context.coordinator.lastBounds != uiView.bounds

      if documentChanged {
         uiView.document = PDFDocument(url: url)
         context.coordinator.refreshCounts()
         context.coordinator.didApplyScroll = false
      }

      if documentChanged || boundsChanged {
         context.coordinator.lastBounds = uiView.bounds
         // Custom scaling disabled; rely on autoScales in makeUIView.
      }

      guard uiView.document != nil, context.coordinator.didApplyScroll == false else {
         return
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
         uiView.goToFirstPage(nil)

         if let scrollView = findScrollView(in: uiView) {
            let targetY = -scrollView.adjustedContentInset.top + scrollDownOffset
            scrollView.setContentOffset(CGPoint(x: 0, y: targetY), animated: false)
            context.coordinator.didApplyScroll = true
         }
      }
   }

   final class Coordinator: NSObject {
      private let parent: PDFKitTestView
      private weak var pdfView: PDFView?
      private weak var observedPanGesture: UIPanGestureRecognizer?
      var didApplyScroll = false
      var lastBounds: CGRect = .zero

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


//   private func applyScaling(to pdfView: PDFView) {
//      pdfView.layoutIfNeeded()
//      let fitScale = pdfView.scaleFactorForSizeToFit * 0.8
//      guard fitScale.isFinite, fitScale > 0 else {
//         return
//      }
//
//      pdfView.minScaleFactor = fitScale
//      pdfView.maxScaleFactor = max(fitScale * 4.0, 2.0)
//      pdfView.scaleFactor = fitScale
//   }

   private func findScrollView(in view: UIView) -> UIScrollView? {
      if let scrollView = view as? UIScrollView {
         return scrollView
      }

      for subview in view.subviews {
         if let found = findScrollView(in: subview) {
            return found
         }
      }

      return nil
   }
}
