import Foundation

public struct CompressionTarget: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let estimatedSizeKb: Int
    public let isLongImage: Bool
    public let targetSizeKb: Int?

    init(
        width: Int,
        height: Int,
        estimatedSizeKb: Int,
        isLongImage: Bool = false,
        targetSizeKb: Int? = nil
    ) {
        self.width = width
        self.height = height
        self.estimatedSizeKb = estimatedSizeKb
        self.isLongImage = isLongImage
        self.targetSizeKb = targetSizeKb
    }
}

public struct CompressionCalculator: Sendable {
    private let baseShort = 1440
    private let wallLong = 10_800
    private let wallRatio = 0.4
    private let trapPixels: Int64 = 40_960_000
    private let capPixels: Int64 = 10_240_000

    public init() {}

    public func calculateTarget(width: Int, height: Int) -> CompressionTarget {
        guard width > 0, height > 0 else {
            return CompressionTarget(width: 0, height: 0, estimatedSizeKb: 0)
        }

        let shortSide = min(width, height)
        let longSide = max(width, height)
        let ratio = Double(shortSide) / Double(longSide)
        let pixelCount = Int64(width) * Int64(height)

        var targetShort = baseShort
        var targetLong = Int(Double(targetShort) / ratio)

        if longSide >= wallLong && ratio > wallRatio {
            targetLong = baseShort
            targetShort = Int(Double(targetLong) * ratio)
        }

        if pixelCount > trapPixels {
            let trapShort = Int(Double(shortSide) * 0.25)
            if trapShort < targetShort {
                targetShort = trapShort
                targetLong = Int(Double(targetShort) / ratio)
            }
        }

        if targetShort > shortSide {
            targetShort = shortSide
            targetLong = longSide
        }

        let currentPixels = Int64(targetShort) * Int64(targetLong)
        if currentPixels > capPixels {
            let scale = (sqrt(Double(capPixels) / Double(currentPixels)) * 1000).rounded(.down) / 1000.0
            targetShort = Int(Double(targetShort) * scale)
            targetLong = Int(Double(targetLong) * scale)
        }

        targetShort = (targetShort / 2) * 2
        targetLong = (targetLong / 2) * 2

        targetShort = max(2, targetShort)
        targetLong = max(2, targetLong)

        let finalW: Int
        let finalH: Int
        if width < height {
            finalW = targetShort
            finalH = targetLong
        } else {
            finalW = targetLong
            finalH = targetShort
        }

        let finalPixels = Int64(finalW) * Int64(finalH)

        let factor: Double
        if finalPixels < 500_000 {
            factor = 0.0005
        } else if finalPixels < 1_000_000 {
            factor = 0.00015
        } else if finalPixels < 3_000_000 {
            factor = 0.00011
        } else {
            factor = 0.000025
        }

        var estimatedSize = Int(Double(finalPixels) * factor)
        estimatedSize = max(20, estimatedSize)

        if ratio < 0.2 && estimatedSize < 400 {
            estimatedSize = max(estimatedSize, 250)
        }

        let isLongImage = ratio <= 0.5
        let targetSizeKb = isLongImage ? estimatedSize : nil

        return CompressionTarget(
            width: finalW,
            height: finalH,
            estimatedSizeKb: estimatedSize,
            isLongImage: isLongImage,
            targetSizeKb: targetSizeKb
        )
    }
}
