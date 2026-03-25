import Foundation
import Resvg

/// Errors that can occur during SVG to PNG conversion
enum SvgToPngConverterError: LocalizedError, Equatable {
    case rasterizationFailed(file: String, reason: String)
    case encodingFailed(file: String, reason: String)

    var errorDescription: String? {
        switch self {
        case let .rasterizationFailed(file, reason):
            "SVG rasterization failed: \(file) - \(reason)"
        case let .encodingFailed(file, reason):
            "PNG encoding failed: \(file) - \(reason)"
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

/// SVG to PNG converter using resvg and native PNG encoder
///
/// Rasterizes SVG images using resvg and encodes to PNG format.
/// Produces higher quality results than Figma's server-side PNG rendering.
struct SvgToPngConverter {
    private let rasterizer: SvgRasterizer

    /// Creates an SVG to PNG converter
    init() {
        rasterizer = SvgRasterizer()
    }

    /// Converts SVG data to PNG data
    /// - Parameters:
    ///   - svgData: SVG file data
    ///   - scale: Scale factor for rasterization (1.0 = native size)
    ///   - fileName: Original file name for error messages
    /// - Returns: PNG encoded data
    /// - Throws: `SvgToPngConverterError` on failure
    func convert(svgData: Data, scale: Double, fileName: String) throws -> Data {
        // Rasterize SVG to RGBA
        let rasterized: RasterizedSvg
        do {
            rasterized = try rasterizer.rasterize(data: svgData, scale: scale)
        } catch let error as ResvgError {
            throw SvgToPngConverterError.rasterizationFailed(
                file: fileName,
                reason: error.localizedDescription
            )
        } catch {
            throw SvgToPngConverterError.rasterizationFailed(
                file: fileName,
                reason: error.localizedDescription
            )
        }

        // Create PNG encoder and encode
        let encoder = NativePngEncoder()
        do {
            return try encoder.encode(
                rgba: rasterized.rgba,
                width: rasterized.width,
                height: rasterized.height
            )
        } catch let error as NativePngEncoderError {
            throw SvgToPngConverterError.encodingFailed(
                file: fileName,
                reason: error.localizedDescription
            )
        } catch {
            throw SvgToPngConverterError.encodingFailed(
                file: fileName,
                reason: error.localizedDescription
            )
        }
    }

    /// Converts SVG data to PNG and writes to file
    /// - Parameters:
    ///   - svgData: SVG file data
    ///   - scale: Scale factor for rasterization (1.0 = native size)
    ///   - outputURL: Output file URL (.png)
    ///   - fileName: Original file name for error messages
    /// - Throws: `SvgToPngConverterError` on failure
    func convert(svgData: Data, scale: Double, to outputURL: URL, fileName: String) throws {
        let pngData = try convert(svgData: svgData, scale: scale, fileName: fileName)
        try pngData.write(to: outputURL)
    }
}
