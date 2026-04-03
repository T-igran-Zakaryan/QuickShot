import CoreGraphics
import ImageIO
import Photos
import UIKit
import Vision

enum DocumentLibraryScanner {
    private static let scanSize = CGSize(width: 480, height: 480)
    private static let maxConcurrentScans = 2
    private static var debugRemaining = 20

    static func scanDocumentAssetIdentifiers(
        from assetIdentifiers: [String],
        progress: @escaping @Sendable (_ completed: Int, _ total: Int) async -> Void
    ) async -> Set<String> {
        let total = assetIdentifiers.count
        guard total > 0 else {
            await progress(0, 0)
            return []
        }

        var matches = Set<String>()
        var completed = 0
        var iterator = assetIdentifiers.makeIterator()

        await withTaskGroup(of: (String, Bool).self) { group in
            let initialTaskCount = min(maxConcurrentScans, total)
            for _ in 0..<initialTaskCount {
                guard let assetIdentifier = iterator.next() else { break }
                group.addTask(priority: .utility) {
                    let isDocumentLike = await isDocumentLikeAsset(withIdentifier: assetIdentifier)
                    return (assetIdentifier, isDocumentLike)
                }
            }

            while let (assetIdentifier, isDocumentLike) = await group.next() {
                completed += 1

                if isDocumentLike {
                    matches.insert(assetIdentifier)
                }

                await progress(completed, total)

                guard !Task.isCancelled, let nextIdentifier = iterator.next() else {
                    continue
                }

                group.addTask(priority: .utility) {
                    let isDocumentLike = await isDocumentLikeAsset(withIdentifier: nextIdentifier)
                    return (nextIdentifier, isDocumentLike)
                }
            }
        }

        return matches
    }

    private static func isDocumentLikeAsset(withIdentifier assetIdentifier: String) async -> Bool {
        guard !Task.isCancelled else { return false }
        guard let asset = fetchAsset(withIdentifier: assetIdentifier) else { return false }
        guard asset.mediaType == .image else { return false }
        guard asset.pixelWidth >= 320, asset.pixelHeight >= 320 else { return false }
        guard let image = await thumbnail(for: asset, targetSize: scanSize) else { return false }

        return autoreleasepool {
            guard let cgImage = image.normalizedCGImage else { return false }
            let orientation = image.cgImagePropertyOrientation

            let hasFace = containsHumanFace(in: cgImage, orientation: orientation)
            let hasHuman = containsHumanFigure(in: cgImage, orientation: orientation)

            let textFeatures = recognizeText(in: cgImage, orientation: orientation)
            let rectangleConfidence = detectRectangleConfidence(in: cgImage, orientation: orientation)
            let brightBackgroundRatio = paperLikeBackgroundRatio(in: cgImage)
            let isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)

            let hasText = textFeatures.characterCount >= 3 || textFeatures.observationCount >= 1
            let rectangleLikely = rectangleConfidence >= 0.25
            let paperStyle = brightBackgroundRatio >= 0.25
            let textCoverage = textFeatures.coverage >= 0.01

            let passes = (isScreenshot && hasText)
                || (rectangleLikely && hasText)
                || (paperStyle && hasText)
                || (hasText && textCoverage)

            if hasFace || hasHuman {
                debugLogDecision(
                    assetIdentifier,
                    hasFace: hasFace,
                    hasHuman: hasHuman,
                    rectangleConfidence: rectangleConfidence,
                    textFeatures: textFeatures,
                    brightBackgroundRatio: brightBackgroundRatio,
                    isScreenshot: isScreenshot,
                    passes: false
                )
                return false
            }

            if !passes {
                debugLogDecision(
                    assetIdentifier,
                    hasFace: hasFace,
                    hasHuman: hasHuman,
                    rectangleConfidence: rectangleConfidence,
                    textFeatures: textFeatures,
                    brightBackgroundRatio: brightBackgroundRatio,
                    isScreenshot: isScreenshot,
                    passes: false
                )
            }

            return passes
        }
    }

    private static func fetchAsset(withIdentifier assetIdentifier: String) -> PHAsset? {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        return result.firstObject
    }

    private static func debugLogDecision(
        _ assetIdentifier: String,
        hasFace: Bool,
        hasHuman: Bool,
        rectangleConfidence: Float,
        textFeatures: RecognizedTextFeatures,
        brightBackgroundRatio: Double,
        isScreenshot: Bool,
        passes: Bool
    ) {
        guard debugRemaining > 0 else { return }
        debugRemaining -= 1
        let shortId = String(assetIdentifier.prefix(8))
        let rectString = String(format: "%.2f", rectangleConfidence)
        let coverageString = String(format: "%.3f", textFeatures.coverage)
        let paperString = String(format: "%.2f", brightBackgroundRatio)
        print(
            "DocScan[\(shortId)] pass=\(passes) face=\(hasFace) human=\(hasHuman) rect=\(rectString) textCount=\(textFeatures.characterCount) obs=\(textFeatures.observationCount) coverage=\(coverageString) paper=\(paperString) screenshot=\(isScreenshot)"
        )
    }

    private static func thumbnail(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.version = .current

            var didResume = false

            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, info in
                if didResume {
                    return
                }

                if let isCancelled = info?[PHImageCancelledKey] as? Bool, isCancelled {
                    didResume = true
                    continuation.resume(returning: nil)
                    return
                }

                if info?[PHImageErrorKey] as? NSError != nil {
                    didResume = true
                    continuation.resume(returning: nil)
                    return
                }

                guard let data, let image = UIImage(data: data) else {
                    didResume = true
                    continuation.resume(returning: nil)
                    return
                }

                didResume = true
                continuation.resume(returning: image)
            }
        }
    }

    private static func recognizeText(
        in cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> RecognizedTextFeatures {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.automaticallyDetectsLanguage = false
        request.minimumTextHeight = 0.008

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)

        do {
            try handler.perform([request])
        } catch {
            return .empty
        }

        let observations = request.results ?? []
        guard !observations.isEmpty else { return .empty }

        var characterCount = 0
        var coverage: CGFloat = 0

        for observation in observations {
            if let candidate = observation.topCandidates(1).first {
                characterCount += candidate.string
                    .filter { !$0.isWhitespace && !$0.isNewline }
                    .count
            }

            coverage += observation.boundingBox.width * observation.boundingBox.height
        }

        return RecognizedTextFeatures(
            observationCount: observations.count,
            characterCount: characterCount,
            coverage: coverage
        )
    }

    private static func detectRectangleConfidence(
        in cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> Float {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumConfidence = 0.2
        request.minimumAspectRatio = 0.35
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.12
        request.quadratureTolerance = 30

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)

        do {
            try handler.perform([request])
        } catch {
            return 0
        }

        return request.results?.first?.confidence ?? 0
    }

    private static func containsHumanFace(
        in cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> Bool {
        let request = VNDetectFaceRectanglesRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)

        do {
            try handler.perform([request])
        } catch {
            return false
        }

        return !(request.results ?? []).isEmpty
    }

    private static func containsHumanFigure(
        in cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> Bool {
        let request = VNDetectHumanRectanglesRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)

        do {
            try handler.perform([request])
        } catch {
            return false
        }

        return (request.results ?? []).contains {
            let area = $0.boundingBox.width * $0.boundingBox.height
            return $0.confidence >= 0.7 && area >= 0.08
        }
    }

    private static func paperLikeBackgroundRatio(in cgImage: CGImage) -> Double {
        let width = 40
        let height = 40
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8

        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return 0
        }

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return 0
        }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var lightPixelCount = 0

        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let red = Double(pixels[index]) / 255
            let green = Double(pixels[index + 1]) / 255
            let blue = Double(pixels[index + 2]) / 255

            let maximum = max(red, green, blue)
            let minimum = min(red, green, blue)
            let saturation = maximum == 0 ? 0 : (maximum - minimum) / maximum
            let brightness = (red * 0.2126) + (green * 0.7152) + (blue * 0.0722)

            if brightness >= 0.72 && saturation <= 0.22 {
                lightPixelCount += 1
            }
        }

        return Double(lightPixelCount) / Double(width * height)
    }

    private static func aspectRatio(of cgImage: CGImage) -> CGFloat {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        guard width > 0, height > 0 else { return 1 }
        return min(width, height) / max(width, height)
    }
}

private struct RecognizedTextFeatures {
    let observationCount: Int
    let characterCount: Int
    let coverage: CGFloat

    static let empty = RecognizedTextFeatures(observationCount: 0, characterCount: 0, coverage: 0)
}

private extension UIImage {
    var normalizedCGImage: CGImage? {
        if let cgImage {
            return cgImage
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }

    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up:
            return .up
        case .down:
            return .down
        case .left:
            return .left
        case .right:
            return .right
        case .upMirrored:
            return .upMirrored
        case .downMirrored:
            return .downMirrored
        case .leftMirrored:
            return .leftMirrored
        case .rightMirrored:
            return .rightMirrored
        @unknown default:
            return .up
        }
    }
}
