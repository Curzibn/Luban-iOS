import Foundation
import ImageIO
import CoreGraphics

struct JpegCompressor {
    private let defaultQuality = 60
    private let probeQuality = 95
    private let minimumQuality = 5

    func compress(_ image: CGImage, targetSizeKb: Int?, fixedQuality: Int?) throws -> Data {
        if let fixedQuality {
            return try encode(image, quality: fixedQuality)
        }

        guard let targetSizeKb else {
            return try encode(image, quality: defaultQuality)
        }

        let probe = try encode(image, quality: probeQuality)
        if kilobytes(probe.count) <= Double(targetSizeKb) {
            return probe
        }

        var low = minimumQuality
        var high = probeQuality
        var best: Data?

        while low <= high {
            let mid = (low + high) / 2
            let compressed = try encode(image, quality: mid)

            if kilobytes(compressed.count) <= Double(targetSizeKb) {
                best = compressed
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        if let best {
            return best
        }
        return try encode(image, quality: minimumQuality)
    }

    private func kilobytes(_ byteCount: Int) -> Double {
        Double(byteCount) / 1024.0
    }

    private func encode(_ image: CGImage, quality: Int) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            jpegTypeIdentifier as CFString,
            1,
            nil
        ) else {
            throw LubanError.encodingFailed
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: Double(quality) / 100.0
        ]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw LubanError.encodingFailed
        }
        return data as Data
    }
}

private let jpegTypeIdentifier = "public.jpeg"
