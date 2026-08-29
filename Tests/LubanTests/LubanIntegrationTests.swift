import XCTest
import CoreGraphics
import ImageIO
@testable import Luban

final class LubanIntegrationTests: XCTestCase {
    private var workDirectory: URL!

    override func setUpWithError() throws {
        workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("luban-ios-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDirectory)
    }

    func testStandardImageShrinksToTargetDimensions() async throws {
        let inputURL = try writeJPEG(width: 3000, height: 4000, quality: 85, name: "standard")
        let outputURL = workDirectory.appendingPathComponent("standard-out.jpg")

        let result = try await Luban.compress(inputURL, to: outputURL)

        let (width, height) = try pixelSize(ofFile: result)
        XCTAssertEqual(width, 1440)
        XCTAssertEqual(height, 1920)
        XCTAssertGreaterThan(FileManager.default.fileSize(of: result), 0)
    }

    func testLongImageStaysWithinTargetSize() async throws {
        let inputURL = try writeJPEG(width: 1000, height: 4000, quality: 92, name: "long")
        let outputURL = workDirectory.appendingPathComponent("long-out.jpg")

        let result = try await Luban.compress(inputURL, to: outputURL)

        let (width, height) = try pixelSize(ofFile: result)
        XCTAssertEqual(width, 1000)
        XCTAssertEqual(height, 4000)

        let sizeBytes = FileManager.default.fileSize(of: result)
        XCTAssertLessThanOrEqual(Double(sizeBytes) / 1024.0, 100.0)
    }

    func testExifRotatedImageIsUprightAfterCompression() async throws {
        let inputURL = try writeJPEG(
            width: 2000,
            height: 3000,
            quality: 90,
            name: "exif",
            orientation: 6,
            cornerMarker: true
        )
        let outputURL = workDirectory.appendingPathComponent("exif-out.jpg")

        let result = try await Luban.compress(inputURL, to: outputURL)

        let (width, height) = try pixelSize(ofFile: result)
        XCTAssertEqual(width, 2160)
        XCTAssertEqual(height, 1440)

        let outputImage = try loadFirstImage(ofFile: result)
        let topRight = try pixel(of: outputImage, x: width * 19 / 20, y: height / 20)
        XCTAssertGreaterThan(topRight.red, 150)
        XCTAssertLessThan(topRight.green, 110)
        let bottomLeft = try pixel(of: outputImage, x: width / 20, y: height * 19 / 20)
        XCTAssertLessThan(bottomLeft.red, 150)
    }

    func testSmallImageIsNeverUpscaled() async throws {
        let inputURL = try writeJPEG(width: 500, height: 300, quality: 88, name: "small")
        let outputURL = workDirectory.appendingPathComponent("small-out.jpg")

        let result = try await Luban.compress(inputURL, to: outputURL)

        let (width, height) = try pixelSize(ofFile: result)
        XCTAssertEqual(width, 500)
        XCTAssertEqual(height, 300)
    }

    func testDegradationGuardFallsBackToOriginalFile() async throws {
        let inputURL = try writeJPEG(width: 800, height: 600, quality: 10, name: "guard")
        let outputURL = workDirectory.appendingPathComponent("guard-out.jpg")

        let result = try await Luban.compress(inputURL, to: outputURL)

        XCTAssertEqual(
            FileManager.default.fileSize(of: result),
            FileManager.default.fileSize(of: inputURL)
        )
    }

    func testBatchCompressionRunsConcurrently() async throws {
        let inputs = [
            try writeJPEG(width: 1920, height: 1080, quality: 85, name: "batch-a"),
            try writeJPEG(width: 1000, height: 4000, quality: 85, name: "batch-b"),
            try writeJPEG(width: 500, height: 300, quality: 85, name: "batch-c")
        ]

        let results = await Luban.compress(inputs, toDirectory: workDirectory)

        XCTAssertEqual(results.count, 3)
        for case .success(let outputURL) in results {
            XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        }
    }

    func testCompressingFromRawData() async throws {
        let data = try makeJPEGData(width: 3000, height: 4000, quality: 85)
        let outputURL = workDirectory.appendingPathComponent("data-out.jpg")

        let result = try await Luban.compress(data, to: outputURL)

        let (width, height) = try pixelSize(ofFile: result)
        XCTAssertEqual(width, 1440)
        XCTAssertEqual(height, 1920)
    }

    func testMissingFileThrows() async {
        let missing = workDirectory.appendingPathComponent("missing.jpg")

        do {
            _ = try await Luban.compress(missing, to: workDirectory.appendingPathComponent("x.jpg"))
            XCTFail("Expected fileDoesNotExist")
        } catch let error as LubanError {
            XCTAssertEqual(error, .fileDoesNotExist(path: missing.path))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    private func writeJPEG(
        width: Int,
        height: Int,
        quality: Int,
        name: String,
        orientation: UInt32? = nil,
        cornerMarker: Bool = false
    ) throws -> URL {
        let data = try makeJPEGData(
            width: width,
            height: height,
            quality: quality,
            orientation: orientation,
            cornerMarker: cornerMarker
        )
        let url = workDirectory.appendingPathComponent("\(name).jpg")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func makeJPEGData(
        width: Int,
        height: Int,
        quality: Int,
        orientation: UInt32? = nil,
        cornerMarker: Bool = false
    ) throws -> Data {
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        else {
            throw XCTSkip("Cannot create drawing context")
        }

        drawGradient(context: context, width: width, height: height, colorSpace: colorSpace)
        drawNoise(context: context, width: width, height: height, colorSpace: colorSpace)

        if cornerMarker {
            context.setFillColor(CGColor(colorSpace: colorSpace, components: [1, 0, 0, 1])!)
            context.fill(CGRect(x: 0, y: CGFloat(height) - 40, width: 40, height: 40))
        }

        guard let image = context.makeImage() else {
            throw XCTSkip("Cannot render test image")
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            throw XCTSkip("Cannot create JPEG destination")
        }

        var properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: Double(quality) / 100.0
        ]
        if let orientation {
            properties[kCGImagePropertyOrientation] = NSNumber(value: orientation)
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func drawGradient(
        context: CGContext,
        width: Int,
        height: Int,
        colorSpace: CGColorSpace
    ) {
        let colors = [
            CGColor(colorSpace: colorSpace, components: [0.10, 0.20, 0.80, 1])!,
            CGColor(colorSpace: colorSpace, components: [0.90, 0.40, 0.10, 1])!
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
            context.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: width, y: height),
                options: []
            )
        }
    }

    private func drawNoise(
        context: CGContext,
        width: Int,
        height: Int,
        colorSpace: CGColorSpace
    ) {
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func nextUnit() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 33) / Double(UInt32.max)
        }

        let patchCount = max(64, width * height / 2000)
        for _ in 0..<patchCount {
            let x = Int(nextUnit() * Double(width))
            let y = Int(nextUnit() * Double(height))
            let size = 2 + Int(nextUnit() * 22)
            let red = nextUnit()
            let green = nextUnit()
            let blue = nextUnit()
            context.setFillColor(
                CGColor(colorSpace: colorSpace, components: [red, green, blue, 1])!
            )
            context.fill(CGRect(x: x, y: y, width: size, height: size))
        }
    }

    private func pixelSize(ofFile url: URL) throws -> (Int, Int) {
        let image = try loadFirstImage(ofFile: url)
        return (image.width, image.height)
    }

    private func loadFirstImage(ofFile url: URL) throws -> CGImage {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw XCTSkip("Cannot decode output image")
        }
        return image
    }

    private func pixel(of image: CGImage, x: Int, y: Int) throws -> (red: UInt8, green: UInt8, blue: UInt8) {
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        else {
            throw XCTSkip("Cannot create sampling context")
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let data = context.data else {
            throw XCTSkip("Cannot read sampling buffer")
        }

        let bytesPerRow = context.bytesPerRow
        let buffer = data.assumingMemoryBound(to: UInt8.self)
        let offset = y * bytesPerRow + x * 4
        return (buffer[offset], buffer[offset + 1], buffer[offset + 2])
    }
}

private extension FileManager {
    func fileSize(of url: URL) -> Int64 {
        let attributes = try? attributesOfItem(atPath: url.path)
        return attributes?[.size] as? Int64 ?? 0
    }
}
