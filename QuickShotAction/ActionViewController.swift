import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ActionViewController: UIViewController {
    @IBOutlet private weak var imageView: UIImageView?

    private let converter = ActionPDFConverter()

    private var sourceImages: [UIImage] = []
    private var conversionPageSize: PDFPageSizeOption = .a4
    private var conversionQuality: Double = 0.85
    private var isConverting = false {
        didSet { hostingController?.rootView = makeRootView() }
    }
    private var statusMessage: String? {
        didSet { hostingController?.rootView = makeRootView() }
    }

    private var hostingController: UIHostingController<ActionRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        embedRootView()

        Task {
            await loadInputImages()
        }
    }

    @IBAction private func done() {
        cancelExtension()
    }

    private func embedRootView() {
        let host = UIHostingController(rootView: makeRootView())
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        hostingController = host
    }

    private func makeRootView() -> ActionRootView {
        ActionRootView(
            pageSize: conversionPageSize,
            compressionQuality: conversionQuality,
            isConverting: isConverting,
            statusMessage: statusMessage,
            onPageSizeChange: { [weak self] value in
                self?.conversionPageSize = value
            },
            onQualityChange: { [weak self] value in
                self?.conversionQuality = value
            },
            onConvert: { [weak self] in
                self?.startConversion()
            },
            onCancel: { [weak self] in
                self?.cancelExtension()
            }
        )
    }

    @MainActor
    private func loadInputImages() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            statusMessage = "No input items found."
            return
        }

        statusMessage = "Loading images..."

        var images: [UIImage] = []
        for item in items {
            let attachments = item.attachments ?? []
            for provider in attachments where provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                if let image = await loadImage(from: provider) {
                    images.append(image)
                }
            }
        }

        sourceImages = images
        if images.isEmpty {
            statusMessage = "No images were provided to convert."
        } else {
            statusMessage = "Ready to convert \(images.count) image\(images.count == 1 ? "" : "s")."
        }
    }

    private func loadImage(from provider: NSItemProvider) async -> UIImage? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                if let image = item as? UIImage {
                    continuation.resume(returning: image)
                    return
                }

                if let url = item as? URL,
                   let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    continuation.resume(returning: image)
                    return
                }

                if let data = item as? Data,
                   let image = UIImage(data: data) {
                    continuation.resume(returning: image)
                    return
                }

                continuation.resume(returning: nil)
            }
        }
    }

    private func startConversion() {
        guard !isConverting else { return }
        guard !sourceImages.isEmpty else {
            statusMessage = "No images available for conversion."
            return
        }

        isConverting = true
        statusMessage = "Converting to PDF..."

        Task { @MainActor in
            let settings = PDFConversionSettings(
                pageSize: conversionPageSize,
                compressionQuality: CGFloat(conversionQuality)
            )

            guard let pdfData = converter.makePDF(from: sourceImages, settings: settings) else {
                isConverting = false
                statusMessage = "Conversion failed."
                return
            }

            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(defaultFileName())
                .appendingPathExtension("pdf")

            do {
                try pdfData.write(to: fileURL, options: .atomic)
                isConverting = false
                statusMessage = "Choose where to save your PDF."
                presentExportPicker(for: fileURL)
            } catch {
                isConverting = false
                statusMessage = "Could not prepare PDF for saving."
            }
        }
    }

    private func presentExportPicker(for url: URL) {
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        picker.delegate = self
        picker.modalPresentationStyle = .formSheet
        present(picker, animated: true)
    }

    private func cancelExtension() {
        extensionContext?.cancelRequest(withError: NSError(domain: "QuickShotAction", code: 1))
    }

    private func defaultFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "QuickShot-\(formatter.string(from: Date()))"
    }
}

extension ActionViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}

private struct ActionRootView: View {
    let isConverting: Bool
    let statusMessage: String?
    let onPageSizeChange: (PDFPageSizeOption) -> Void
    let onQualityChange: (Double) -> Void
    let onConvert: () -> Void
    let onCancel: () -> Void

    @State private var pageSize: PDFPageSizeOption
    @State private var compressionQuality: Double

    init(
        pageSize: PDFPageSizeOption,
        compressionQuality: Double,
        isConverting: Bool,
        statusMessage: String?,
        onPageSizeChange: @escaping (PDFPageSizeOption) -> Void,
        onQualityChange: @escaping (Double) -> Void,
        onConvert: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        _pageSize = State(initialValue: pageSize)
        _compressionQuality = State(initialValue: compressionQuality)
        self.isConverting = isConverting
        self.statusMessage = statusMessage
        self.onPageSizeChange = onPageSizeChange
        self.onQualityChange = onQualityChange
        self.onConvert = onConvert
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Size settings") {
                    Picker("Page size", selection: Binding(
                        get: { pageSize },
                        set: {
                            pageSize = $0
                            onPageSizeChange($0)
                        }
                    )) {
                        Text("A4").tag(PDFPageSizeOption.a4)
                        Text("Keep image size").tag(PDFPageSizeOption.keepOriginal)
                        Text("Fit all images").tag(PDFPageSizeOption.fitAll)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Compression settings") {
                    Slider(
                        value: Binding(
                            get: { compressionQuality },
                            set: {
                                compressionQuality = $0
                                onQualityChange($0)
                            }
                        ),
                        in: 0.4...1.0,
                        step: 0.05
                    )
                    HStack {
                        Text("Smaller file")
                        Spacer()
                        Text("Better quality")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if let statusMessage {
                    Section {
                        HStack(spacing: 8) {
                            if isConverting {
                                ProgressView()
                            }
                            Text(statusMessage)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Conversion Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isConverting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Convert", action: onConvert)
                        .disabled(isConverting)
                }
            }
        }
    }
}

private enum PDFPageSizeOption: String, CaseIterable, Identifiable {
    case a4
    case keepOriginal
    case fitAll

    var id: String { rawValue }
}

private struct PDFConversionSettings {
    let pageSize: PDFPageSizeOption
    let compressionQuality: CGFloat
}

private final class ActionPDFConverter {
    func makePDF(from images: [UIImage], settings: PDFConversionSettings) -> Data? {
        guard !images.isEmpty else { return nil }

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, .zero, nil)

        for image in images {
            let size = image.size
            guard size.width > 0, size.height > 0 else { continue }

            let pageRect = pageRect(for: size, option: settings.pageSize)
            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)

            let renderImage = compressedImage(from: image, quality: settings.compressionQuality) ?? image
            let drawRect = drawRect(for: renderImage.size, in: pageRect, option: settings.pageSize)
            renderImage.draw(in: drawRect)
        }

        UIGraphicsEndPDFContext()
        return data as Data
    }

    private func pageRect(for imageSize: CGSize, option: PDFPageSizeOption) -> CGRect {
        switch option {
        case .keepOriginal:
            return CGRect(origin: .zero, size: imageSize)
        case .a4:
            return CGRect(origin: .zero, size: CGSize(width: 595.2, height: 841.8))
        case .fitAll:
            return CGRect(origin: .zero, size: CGSize(width: 612, height: 792))
        }
    }

    private func drawRect(for imageSize: CGSize, in pageRect: CGRect, option: PDFPageSizeOption) -> CGRect {
        switch option {
        case .keepOriginal:
            return pageRect
        case .a4, .fitAll:
            let scale = min(pageRect.width / imageSize.width, pageRect.height / imageSize.height)
            let targetSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let origin = CGPoint(
                x: (pageRect.width - targetSize.width) / 2.0,
                y: (pageRect.height - targetSize.height) / 2.0
            )
            return CGRect(origin: origin, size: targetSize)
        }
    }

    private func compressedImage(from image: UIImage, quality: CGFloat) -> UIImage? {
        guard quality < 0.98 else { return image }
        guard let data = image.jpegData(compressionQuality: quality) else { return nil }
        return UIImage(data: data)
    }
}
