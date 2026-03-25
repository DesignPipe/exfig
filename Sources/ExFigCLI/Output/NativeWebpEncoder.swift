import Foundation
import libwebp
import WebP

/// Errors that can occur during WebP encoding
enum NativeWebpEncoderError: LocalizedError, Equatable {
    case invalidDimensions
    case invalidRgbaData(expected: Int, actual: Int)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidDimensions:
            "Invalid image dimensions: width and height must be > 0"
        case let .invalidRgbaData(expected, actual):
            "Invalid RGBA data: expected \(expected) bytes, got \(actual)"
        case .encodingFailed:
            "WebP encoding failed"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidDimensions:
            "Ensure the source image has valid dimensions"
        case .invalidRgbaData:
            "Re-export the source image from Figma"
        case .encodingFailed:
            "Try re-exporting the source image or use a different format"
        }
    }
}

/// Encodes RGBA pixel data to WebP format using native libwebp
///
/// Uses the `the-swift-collective/libwebp` Swift package which provides
/// bindings to libwebp 1.4.x for WebP image encoding.
struct NativeWebpEncoder {
    /// WebP encoding quality (0-100)
    /// Only used for lossy encoding. Higher values = better quality, larger files.
    let quality: Int

    /// Whether to use lossless encoding
    let lossless: Bool

    /// Creates a WebP encoder
    /// - Parameters:
    ///   - quality: Encoding quality 0-100 (only used for lossy)
    ///   - lossless: If true, uses lossless encoding (ignores quality)
    init(quality: Int = 90, lossless: Bool = false) {
        self.quality = min(100, max(0, quality))
        self.lossless = lossless
    }

    /// Encodes RGBA pixel data to WebP bytes
    /// - Parameters:
    ///   - rgba: Raw RGBA pixel data (4 bytes per pixel)
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    /// - Returns: WebP encoded data
    /// - Throws: `NativeWebpEncoderError` on failure
    func encode(rgba: [UInt8], width: Int, height: Int) throws -> [UInt8] {
        // Validate dimensions
        guard width > 0, height > 0 else {
            throw NativeWebpEncoderError.invalidDimensions
        }

        // Validate RGBA data size
        let expectedSize = width * height * 4
        guard rgba.count == expectedSize else {
            throw NativeWebpEncoderError.invalidRgbaData(expected: expectedSize, actual: rgba.count)
        }

        if lossless {
            // Use native libwebp lossless encoding
            return try encodeLossless(rgba: rgba, width: width, height: height)
        } else {
            // Use WebP wrapper for lossy encoding
            let webp = WebP(width: width, height: height, rgba: rgba)
            do {
                return try webp.encode(quality: Float(quality))
            } catch {
                throw NativeWebpEncoderError.encodingFailed
            }
        }
    }

    /// Encodes RGBA pixel data to lossless WebP using native libwebp API.
    private func encodeLossless(rgba: [UInt8], width: Int, height: Int) throws -> [UInt8] {
        var output: UnsafeMutablePointer<UInt8>?
        let stride = Int32(width * 4)

        let size = WebPEncodeLosslessRGBA(
            rgba,
            Int32(width),
            Int32(height),
            stride,
            &output
        )

        guard size > 0, let outputData = output else {
            throw NativeWebpEncoderError.encodingFailed
        }

        let result = [UInt8](Data(bytes: outputData, count: Int(size)))
        WebPFree(outputData)
        return result
    }

    /// Encodes RGBA pixel data to WebP file
    /// - Parameters:
    ///   - rgba: Raw RGBA pixel data (4 bytes per pixel)
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - outputURL: Output file URL (.webp)
    /// - Throws: `NativeWebpEncoderError` on encoding failure
    func encode(rgba: [UInt8], width: Int, height: Int, to outputURL: URL) throws {
        let webpData = try encode(rgba: rgba, width: width, height: height)
        try Data(webpData).write(to: outputURL)
    }
}
