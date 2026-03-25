import ExFigCore
import Foundation

/// Progress callback type for conversion operations
typealias ConversionProgressCallback = @Sendable (Int, Int) async -> Void

/// Errors that can occur during WebP conversion
enum WebpConverterError: LocalizedError, Equatable {
    case fileNotFound(path: String)
    case invalidInputFormat(path: String)
    case encodingFailed(file: String, reason: String)

    var errorDescription: String? {
        switch self {
        case let .fileNotFound(path):
            "File not found: \(path)"
        case let .invalidInputFormat(path):
            "Invalid PNG format: \(path)"
        case let .encodingFailed(file, reason):
            "WebP encoding failed: \(file) - \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            "Check that the file path exists"
        case .invalidInputFormat:
            "Ensure the file is a valid PNG image"
        case .encodingFailed:
            "Try re-exporting the source image from Figma"
        }
    }
}

/// PNG to WebP converter using native libwebp
///
/// Converts PNG images to WebP format using the native libwebp library.
/// No external binaries (like cwebp) are required.
final class WebpConverter: Sendable {
    /// WebP encoding mode
    enum Encoding {
        case lossy(quality: Int)
        case lossless
    }

    private let encoding: Encoding
    private let maxConcurrent: Int

    /// Creates a WebP converter
    /// - Parameters:
    ///   - encoding: WebP encoding type (lossy or lossless)
    ///   - maxConcurrent: Maximum number of parallel conversions (default: 4)
    init(encoding: Encoding, maxConcurrent: Int = 4) {
        self.encoding = encoding
        self.maxConcurrent = maxConcurrent
    }

    /// Native WebP conversion is always available (no external dependencies)
    /// - Returns: Always returns true
    static func isAvailable() -> Bool {
        true
    }

    /// Converts a single PNG file to WebP
    /// - Parameter url: Path to PNG file
    /// - Throws: `WebpConverterError` on failure
    func convert(file url: URL) throws {
        try convertSync(file: url)
    }

    /// Converts multiple PNG files to WebP in parallel
    /// - Parameters:
    ///   - files: PNG files to convert
    ///   - onProgress: Optional callback called with (current, total) after each conversion
    /// - Throws: `WebpConverterError` on failure
    func convertBatch(
        files: [URL],
        onProgress: ConversionProgressCallback? = nil
    ) async throws {
        guard !files.isEmpty else { return }

        let totalCount = files.count

        try await withThrowingTaskGroup(of: Void.self) { [self] group in
            var iterator = files.makeIterator()
            var activeCount = 0
            var convertedCount = 0

            // Start initial batch
            for _ in 0 ..< min(maxConcurrent, files.count) {
                if let file = iterator.next() {
                    group.addTask { [file] in
                        try self.convertSync(file: file)
                    }
                    activeCount += 1
                }
            }

            // Process completed and start new ones
            for try await _ in group {
                activeCount -= 1
                convertedCount += 1

                // Report progress
                if let onProgress {
                    await onProgress(convertedCount, totalCount)
                }

                if let file = iterator.next() {
                    group.addTask { [file] in
                        try self.convertSync(file: file)
                    }
                    activeCount += 1
                }
            }
        }
    }

    /// Synchronous conversion using native libwebp
    private func convertSync(file url: URL) throws {
        // Verify input file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw WebpConverterError.fileNotFound(path: url.path)
        }

        // Decode PNG to RGBA
        let pngDecoder = PngDecoder()
        let decodedPng: DecodedPng
        do {
            decodedPng = try pngDecoder.decode(file: url)
        } catch let error as PngDecoderError {
            switch error {
            case .invalidFormat, .decodingFailed:
                throw WebpConverterError.invalidInputFormat(path: url.path)
            case let .fileNotFound(path):
                throw WebpConverterError.fileNotFound(path: path)
            }
        }

        // Create WebP encoder based on encoding mode
        let encoder = switch encoding {
        case let .lossy(quality):
            NativeWebpEncoder(quality: quality, lossless: false)
        case .lossless:
            NativeWebpEncoder(lossless: true)
        }

        // Encode to WebP
        let outputURL = url.deletingPathExtension().appendingPathExtension("webp")
        do {
            try encoder.encode(
                rgba: decodedPng.rgba,
                width: decodedPng.width,
                height: decodedPng.height,
                to: outputURL
            )
        } catch let error as NativeWebpEncoderError {
            throw WebpConverterError.encodingFailed(
                file: url.lastPathComponent,
                reason: error.localizedDescription
            )
        }
    }
}
