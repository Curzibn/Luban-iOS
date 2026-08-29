import Foundation
import ImageIO
import CoreGraphics

struct LoadedImage {
    let image: CGImage
    let target: CompressionTarget
    let originalSizeBytes: Int64
}

struct ImageLoader {
    func load(fileURL: URL, calculator: CompressionCalculator) throws -> LoadedImage {
        guard
            let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
            let properties = copyProperties(source)
        else {
            throw LubanError.cannotOpenSource
        }

        let fileSizeBytes = fileSizeBytes(at: fileURL)
        return try load(
            source: source,
            properties: properties,
            originalSizeBytes: fileSizeBytes,
            calculator: calculator
        )
    }

    func load(data: Data, calculator: CompressionCalculator) throws -> LoadedImage {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = copyProperties(source)
        else {
            throw LubanError.cannotOpenSource
        }

        return try load(
            source: source,
            properties: properties,
            originalSizeBytes: Int64(data.count),
            calculator: calculator
        )
    }

    private func copyProperties(_ source: CGImageSource) -> [CFString: Any]? {
        CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    }

    private func fileSizeBytes(at fileURL: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        return attributes?[.size] as? Int64 ?? 0
    }

    private func load(
        source: CGImageSource,
        properties: [CFString: Any],
        originalSizeBytes: Int64,
        calculator: CompressionCalculator
    ) throws -> LoadedImage {
        guard
            let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int,
            let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int,
            pixelWidth > 0,
            pixelHeight > 0
        else {
            throw LubanError.cannotDecode
        }

        let target = calculator.calculateTarget(width: pixelWidth, height: pixelHeight)
        let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1

        let decoded = try decode(
            source: source,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            targetWidth: target.width,
            targetHeight: target.height
        )
        let scaled = try redraw(decoded, toWidth: target.width, toHeight: target.height)
        let oriented = try applyOrientation(scaled, exifOrientation: orientation)

        return LoadedImage(
            image: oriented,
            target: target,
            originalSizeBytes: originalSizeBytes
        )
    }

    private func decode(
        source: CGImageSource,
        pixelWidth: Int,
        pixelHeight: Int,
        targetWidth: Int,
        targetHeight: Int
    ) throws -> CGImage {
        let maxTarget = max(targetWidth, targetHeight)
        let maxOriginal = max(pixelWidth, pixelHeight)

        if maxOriginal <= maxTarget {
            guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw LubanError.cannotDecode
            }
            return image
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: false,
            kCGImageSourceThumbnailMaxPixelSize: maxTarget,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw LubanError.cannotDecode
        }
        return thumbnail
    }

    private func redraw(_ image: CGImage, toWidth: Int, toHeight: Int) throws -> CGImage {
        guard image.width != toWidth || image.height != toHeight else {
            return image
        }

        guard let context = makeContext(width: toWidth, height: toHeight) else {
            throw LubanError.cannotDecode
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: toWidth, height: toHeight))
        guard let output = context.makeImage() else {
            throw LubanError.cannotDecode
        }
        return output
    }

    private func applyOrientation(_ image: CGImage, exifOrientation: UInt32) throws -> CGImage {
        let degrees: Int
        switch exifOrientation {
        case 3: degrees = 180
        case 6: degrees = 90
        case 8: degrees = 270
        default: degrees = 0
        }

        guard degrees != 0 else {
            return image
        }

        let sourceWidth = CGFloat(image.width)
        let sourceHeight = CGFloat(image.height)
        let swapsSides = degrees == 90 || degrees == 270
        let outputWidth = swapsSides ? Int(sourceHeight) : Int(sourceWidth)
        let outputHeight = swapsSides ? Int(sourceWidth) : Int(sourceHeight)

        guard let context = makeContext(width: outputWidth, height: outputHeight) else {
            throw LubanError.cannotDecode
        }
        context.interpolationQuality = .high

        switch degrees {
        case 90:
            context.translateBy(x: 0, y: sourceWidth)
            context.rotate(by: -.pi / 2)
        case 180:
            context.translateBy(x: sourceWidth, y: sourceHeight)
            context.rotate(by: .pi)
        case 270:
            context.translateBy(x: sourceHeight, y: 0)
            context.rotate(by: .pi / 2)
        default:
            break
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: sourceWidth, height: sourceHeight))
        guard let output = context.makeImage() else {
            throw LubanError.cannotDecode
        }
        return output
    }

    private func makeContext(width: Int, height: Int) -> CGContext? {
        guard
            width > 0,
            height > 0,
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        else {
            return nil
        }
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
    }
}
