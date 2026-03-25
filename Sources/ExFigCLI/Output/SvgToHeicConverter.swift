import Foundation
import Resvg

/// Errors that can occur during SVG to HEIC conversion
enum SvgToHeicConverterError: LocalizedError, Equatable {
    case rasterizationFailed(file: String, reason: String)
    case encodingFailed(file: String, reason: String)
    case platformNotSupported

    var errorDescription: String? {
        switch self {
        case let .rasterizationFailed(file, reason):
            "SVG rasterization failed: \(file) - \(reason)"
        case let .encodingFailed(file, reason):
            "HEIC encoding failed: \(file) - \(reason)"
        case .platformNotSupported:
            "HEIC encoding is not supported on this platform"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .rasterizationFailed:
            "Re-export the SVG from Figma or check for unsupported SVG features"
        case .encodingFailed:
            "Try re-exporting the source image or use PNG format instead"
        case .platformNotSupported:
            "Use macOS for HEIC export or choose PNG format"
        }
    }
}

/// SVG to HEIC converter using resvg and ImageIO
///
/// Rasterizes SVG images using resvg and encodes to HEIC format using ImageIO.
/// Produces higher quality results than Figma's server-side PNG rendering with
/// ~40-50% smaller file sizes.
///
/// **macOS only** - use `isAvailable()` to check platform support.
struct SvgToHeicConverter {
    /// HEIC encoding mode
    enum Encoding {
        case lossy(quality: Int)
        case lossless
    }

    private let encoding: Encoding
    private let rasterizer: SvgRasterizer

    /// Creates an SVG to HEIC converter
    /// - Parameter encoding: HEIC encoding type (lossy or lossless)
    init(encoding: Encoding) {
        self.encoding = encoding
        rasterizer = SvgRasterizer()
    }

    /// Checks if HEIC conversion is available on this platform
    /// - Returns: true on macOS 10.13.4+, false on Linux
    static func isAvailable() -> Bool {
        NativeHeicEncoder.isAvailable()
    }

    /// Converts SVG data to HEIC data
    /// - Parameters:
    ///   - svgData: SVG file data
    ///   - scale: Scale factor for rasterization (1.0 = native size)
    ///   - fileName: Original file name for error messages
    /// - Returns: HEIC encoded data
    /// - Throws: `SvgToHeicConverterError` on failure
    func convert(svgData: Data, scale: Double, fileName: String) throws -> Data {
        guard Self.isAvailable() else {
            throw SvgToHeicConverterError.platformNotSupported
        }

        // Rasterize SVG to RGBA
        let rasterized: RasterizedSvg
        do {
            rasterized = try rasterizer.rasterize(data: svgData, scale: scale)
        } catch let error as ResvgError {
            throw SvgToHeicConverterError.rasterizationFailed(
                file: fileName,
                reason: error.localizedDescription
            )
        } catch {
            throw SvgToHeicConverterError.rasterizationFailed(
                file: fileName,
                reason: error.localizedDescription
            )
        }

        // Create HEIC encoder based on encoding mode
        let encoder = switch encoding {
        case let .lossy(quality):
            NativeHeicEncoder(quality: quality, lossless: false)
        case .lossless:
            NativeHeicEncoder(lossless: true)
        }

        // Encode to HEIC
        do {
            return try encoder.encode(
                rgba: rasterized.rgba,
                width: rasterized.width,
                height: rasterized.height
            )
        } catch let error as NativeHeicEncoderError {
            throw SvgToHeicConverterError.encodingFailed(
                file: fileName,
                reason: error.localizedDescription
            )
        } catch {
            throw SvgToHeicConverterError.encodingFailed(
                file: fileName,
                reason: error.localizedDescription
            )
        }
    }

    /// Converts SVG data to HEIC and writes to file
    /// - Parameters:
    ///   - svgData: SVG file data
    ///   - scale: Scale factor for rasterization (1.0 = native size)
    ///   - outputURL: Output file URL (.heic)
    ///   - fileName: Original file name for error messages
    /// - Throws: `SvgToHeicConverterError` on failure
    func convert(svgData: Data, scale: Double, to outputURL: URL, fileName: String) throws {
        let heicData = try convert(svgData: svgData, scale: scale, fileName: fileName)
        try heicData.write(to: outputURL)
    }
}
