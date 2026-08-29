import Foundation

public enum LubanError: Error, Equatable {
    case fileDoesNotExist(path: String)
    case cannotOpenSource
    case cannotDecode
    case encodingFailed
    case outputDirectoryCreationFailed(path: String)
}

public enum Luban {
    public static let version = "0.1.0"

    public typealias CompressionResult = Result<URL, Error>

    public static func compress(_ inputURL: URL, to outputURL: URL) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            try process(input: .file(inputURL), output: outputURL)
        }.value
    }

    public static func compress(_ imageData: Data, to outputURL: URL) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            try process(input: .data(imageData), output: outputURL)
        }.value
    }

    public static func compress(_ inputURL: URL, toDirectory outputDirectory: URL) async throws -> URL {
        let outputURL = generateOutputURL(
            inputName: inputURL.deletingPathExtension().lastPathComponent,
            directory: outputDirectory
        )
        return try await compress(inputURL, to: outputURL)
    }

    public static func compress(_ inputURLs: [URL], toDirectory outputDirectory: URL) async -> [CompressionResult] {
        await withTaskGroup(of: (Int, CompressionResult).self) { group in
            for (index, inputURL) in inputURLs.enumerated() {
                group.addTask {
                    do {
                        let outputURL = try await compress(inputURL, toDirectory: outputDirectory)
                        return (index, .success(outputURL))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }

            var results = [CompressionResult?](repeating: nil, count: inputURLs.count)
            for await (index, result) in group {
                results[index] = result
            }
            return results.compactMap { $0 }
        }
    }

    static func generateOutputURL(inputName: String, directory: URL) -> URL {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let unique = UUID().uuidString.prefix(8).lowercased()
        return directory.appendingPathComponent("\(inputName)_\(timestamp)_\(unique).jpg")
    }

    private enum Input {
        case file(URL)
        case data(Data)
    }

    private static func process(input: Input, output: URL) throws -> URL {
        guard !output.deletingLastPathComponent().path.isEmpty else {
            throw LubanError.outputDirectoryCreationFailed(path: output.path)
        }

        let loaded: LoadedImage
        switch input {
        case .file(let url):
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw LubanError.fileDoesNotExist(path: url.path)
            }
            loaded = try ImageLoader().load(fileURL: url, calculator: CompressionCalculator())
        case .data(let data):
            loaded = try ImageLoader().load(data: data, calculator: CompressionCalculator())
        }

        let fixedQuality: Int? = loaded.target.isLongImage ? nil : 60
        let compressed = try JpegCompressor().compress(
            loaded.image,
            targetSizeKb: loaded.target.targetSizeKb,
            fixedQuality: fixedQuality
        )

        let outputDirectory = output.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: outputDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            } catch {
                throw LubanError.outputDirectoryCreationFailed(path: outputDirectory.path)
            }
        }

        if Int64(compressed.count) >= loaded.originalSizeBytes {
            switch input {
            case .file(let url):
                try? FileManager.default.removeItem(at: output)
                try FileManager.default.copyItem(at: url, to: output)
            case .data(let data):
                try data.write(to: output, options: .atomic)
            }
        } else {
            try compressed.write(to: output, options: .atomic)
        }

        return output
    }
}
