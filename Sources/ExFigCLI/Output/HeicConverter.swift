import ExFigCore
import Foundation

/// Errors that can occur during HEIC conversion
enum HeicConverterError: LocalizedError, Equatable {
    case fileNotFound(path: String)
    case invalidInputFormat(path: String)
    case encodingFailed(file: String, reason: String)
    case platformNotSupported

    var errorDescription: String? {
        switch self {
        case let .fileNotFound(path):
            "File not found: \(path)"
        case let .invalidInputFormat(path):
            "Invalid PNG format: \(path)"
        case let .encodingFailed(file, reason):
            "HEIC encoding failed: \(file) - \(reason)"
        case .platformNotSupported:
            "HEIC encoding is not supported on this platform"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            "Check that the file path exists"
        case .invalidInputFormat:
            "Ensure the file is a valid PNG image"
        case .encodingFailed:
            "Try re-exporting the source image from Figma or use PNG format"
        case .platformNotSupported:
            "Use macOS for HEIC export or choose PNG format"
        }
    }
}

/// PNG to HEIC converter using native ImageIO
///
/// Converts PNG images to HEIC format using the native ImageIO library.
/// HEIC provides ~40-50% smaller file sizes than PNG while maintaining transparency.
///
/// **macOS only** - use `isAvailable()` to check platform support.
final class HeicConverter: Sendable {
    /// HEIC encoding mode
    enum Encoding {
        case lossy(quality: Int)
        case lossless
    }

    private let encoding: Encoding
    private let maxConcurrent: Int

    /// Creates a HEIC converter
    /// - Parameters:
    ///   - encoding: HEIC encoding type (lossy or lossless)
    ///   - maxConcurrent: Maximum number of parallel conversions (default: 4)
    init(encoding: Encoding, maxConcurrent: Int = 4) {
        self.encoding = encoding
        self.maxConcurrent = maxConcurrent
    }

    /// Checks if HEIC conversion is available on this platform
    /// - Returns: true on macOS 10.13.4+, false on Linux
    static func isAvailable() -> Bool {
        NativeHeicEncoder.isAvailable()
    }

    /// Converts a single PNG file to HEIC
    /// - Parameter url: Path to PNG file
    /// - Throws: `HeicConverterError` on failure
    func convert(file url: URL) throws {
        try convertSync(file: url)
    }

    /// Converts multiple PNG files to HEIC in parallel
    /// - Parameters:
    ///   - files: PNG files to convert
    ///   - onProgress: Optional callback called with (current, total) after each conversion
    /// - Throws: `HeicConverterError` on failure
    func convertBatch(
        files: [URL],
        onProgress: ConversionProgressCallback? = nil
    ) async throws {
        guard !files.isEmpty else { return }

        guard Self.isAvailable() else {
            throw HeicConverterError.platformNotSupported
        }

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

    /// Synchronous conversion using native ImageIO
    private func convertSync(file url: URL) throws {
        guard Self.isAvailable() else {
            throw HeicConverterError.platformNotSupported
        }

        // Verify input file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw HeicConverterError.fileNotFound(path: url.path)
        }

        // Decode PNG to RGBA
        let pngDecoder = PngDecoder()
        let decodedPng: DecodedPng
        do {
            decodedPng = try pngDecoder.decode(file: url)
        } catch let error as PngDecoderError {
            switch error {
            case .invalidFormat, .decodingFailed:
                throw HeicConverterError.invalidInputFormat(path: url.path)
            case let .fileNotFound(path):
                throw HeicConverterError.fileNotFound(path: path)
            }
        }

        // Create HEIC encoder based on encoding mode
        let encoder = switch encoding {
        case let .lossy(quality):
            NativeHeicEncoder(quality: quality, lossless: false)
        case .lossless:
            NativeHeicEncoder(lossless: true)
        }

        // Encode to HEIC
        let outputURL = url.deletingPathExtension().appendingPathExtension("heic")
        do {
            try encoder.encode(
                rgba: decodedPng.rgba,
                width: decodedPng.width,
                height: decodedPng.height,
                to: outputURL
            )
        } catch let error as NativeHeicEncoderError {
            throw HeicConverterError.encodingFailed(
                file: url.lastPathComponent,
                reason: error.localizedDescription
            )
        }
    }
}
