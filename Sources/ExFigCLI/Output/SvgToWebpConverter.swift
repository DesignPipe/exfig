import Foundation
import Resvg

/// Errors that can occur during SVG to WebP conversion
enum SvgToWebpConverterError: LocalizedError, Equatable {
    case rasterizationFailed(file: String, reason: String)
    case encodingFailed(file: String, reason: String)

    var errorDescription: String? {
        switch self {
        case let .rasterizationFailed(file, reason):
            "SVG rasterization failed: \(file) - \(reason)"
        case let .encodingFailed(file, reason):
            "WebP encoding failed: \(file) - \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .rasterizationFailed:
            "Re-export the SVG from Figma or check for unsupported SVG features"
        case .encodingFailed:
            "Try re-exporting the source image or use a different format"
        }
    }
}

/// SVG to WebP converter using resvg and libwebp
///
/// Rasterizes SVG images using resvg and encodes to WebP format using libwebp.
/// Produces higher quality results than Figma's server-side PNG rendering.
struct SvgToWebpConverter {
    /// WebP encoding mode
    enum Encoding {
        case lossy(quality: Int)
        case lossless
    }

    private let encoding: Encoding
    private let rasterizer: SvgRasterizer

    /// Creates an SVG to WebP converter
    /// - Parameter encoding: WebP encoding type (lossy or lossless)
    init(encoding: Encoding) {
        self.encoding = encoding
        rasterizer = SvgRasterizer()
    }

    /// Converts SVG data to WebP data
    /// - Parameters:
    ///   - svgData: SVG file data
    ///   - scale: Scale factor for rasterization (1.0 = native size)
    ///   - fileName: Original file name for error messages
    /// - Returns: WebP encoded data
    /// - Throws: `SvgToWebpConverterError` on failure
    func convert(svgData: Data, scale: Double, fileName: String) throws -> Data {
        // Rasterize SVG to RGBA
        let rasterized: RasterizedSvg
        do {
            rasterized = try rasterizer.rasterize(data: svgData, scale: scale)
        } catch let error as ResvgError {
            throw SvgToWebpConverterError.rasterizationFailed(
                file: fileName,
                reason: error.localizedDescription
            )
        } catch {
            throw SvgToWebpConverterError.rasterizationFailed(
                file: fileName,
                reason: error.localizedDescription
            )
        }

        // Create WebP encoder based on encoding mode
        let encoder = switch encoding {
        case let .lossy(quality):
            NativeWebpEncoder(quality: quality, lossless: false)
        case .lossless:
            NativeWebpEncoder(lossless: true)
        }

        // Encode to WebP
        do {
            let webpBytes = try encoder.encode(
                rgba: rasterized.rgba,
                width: rasterized.width,
                height: rasterized.height
            )
            return Data(webpBytes)
        } catch let error as NativeWebpEncoderError {
            throw SvgToWebpConverterError.encodingFailed(
                file: fileName,
                reason: error.localizedDescription
            )
        } catch {
            throw SvgToWebpConverterError.encodingFailed(
                file: fileName,
                reason: error.localizedDescription
            )
        }
    }

    /// Converts SVG data to WebP and writes to file
    /// - Parameters:
    ///   - svgData: SVG file data
    ///   - scale: Scale factor for rasterization (1.0 = native size)
    ///   - outputURL: Output file URL (.webp)
    ///   - fileName: Original file name for error messages
    /// - Throws: `SvgToWebpConverterError` on failure
    func convert(svgData: Data, scale: Double, to outputURL: URL, fileName: String) throws {
        let webpData = try convert(svgData: svgData, scale: scale, fileName: fileName)
        try webpData.write(to: outputURL)
    }
}
