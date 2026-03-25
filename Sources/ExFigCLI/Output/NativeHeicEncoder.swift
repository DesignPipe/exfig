import Foundation

#if canImport(CoreGraphics) && canImport(ImageIO)
    import CoreGraphics
    import ImageIO
    import UniformTypeIdentifiers
#endif

/// Errors that can occur during HEIC encoding
enum NativeHeicEncoderError: LocalizedError, Equatable {
    case invalidDimensions
    case invalidRgbaData(expected: Int, actual: Int)
    case dataProviderCreationFailed
    case colorSpaceCreationFailed
    case cgImageCreationFailed
    case destinationCreationFailed
    case finalizationFailed(lossless: Bool, quality: Double)
    case platformNotSupported

    var errorDescription: String? {
        switch self {
        case .invalidDimensions:
            "Invalid image dimensions: width and height must be > 0"
        case let .invalidRgbaData(expected, actual):
            "Invalid RGBA data: expected \(expected) bytes, got \(actual)"
        case .dataProviderCreationFailed:
            "Failed to create CGDataProvider from RGBA data"
        case .colorSpaceCreationFailed:
            "Failed to create sRGB color space"
        case .cgImageCreationFailed:
            "Failed to create CGImage from RGBA data"
        case .destinationCreationFailed:
            "Failed to create HEIC image destination"
        case let .finalizationFailed(lossless, quality):
            "HEIC encoding failed: lossless=\(lossless), quality=\(quality)"
        case .platformNotSupported:
            "HEIC encoding is not supported on this platform"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidDimensions:
            "Ensure the source image has valid dimensions"
        case .invalidRgbaData:
            "Re-export the source image from Figma"
        case .dataProviderCreationFailed, .colorSpaceCreationFailed, .cgImageCreationFailed:
            "This is an internal error - please report it"
        case .destinationCreationFailed:
            "HEIC codec may not be available on this system"
        case .finalizationFailed:
            "Try using lossy encoding or PNG format instead"
        case .platformNotSupported:
            "Use macOS for HEIC export or choose PNG format"
        }
    }
}

/// Encodes RGBA pixel data to HEIC format using Apple ImageIO
///
/// Uses native ImageIO APIs for HEIC encoding on macOS.
/// HEIC provides ~40-50% smaller file sizes than PNG while maintaining transparency.
///
/// **macOS only** - on Linux, use `isAvailable()` to check and fall back to PNG.
struct NativeHeicEncoder {
    /// HEIC encoding quality (0-100)
    /// Only used for lossy encoding. Higher values = better quality, larger files.
    let quality: Int

    /// Whether to use lossless encoding
    let lossless: Bool

    /// Creates a HEIC encoder
    /// - Parameters:
    ///   - quality: Encoding quality 0-100 (only used for lossy)
    ///   - lossless: If true, uses lossless encoding (ignores quality)
    init(quality: Int = 90, lossless: Bool = false) {
        self.quality = min(100, max(0, quality))
        self.lossless = lossless
    }

    /// Checks if HEIC encoding is available on this platform
    /// - Returns: true on macOS 10.13.4+, false on Linux
    static func isAvailable() -> Bool {
        #if canImport(CoreGraphics) && canImport(ImageIO)
            if #available(macOS 10.13.4, *) {
                return true
            }
            return false
        #else
            return false
        #endif
    }

    /// Encodes RGBA pixel data to HEIC bytes
    /// - Parameters:
    ///   - rgba: Raw RGBA pixel data (4 bytes per pixel)
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    /// - Returns: HEIC encoded data
    /// - Throws: `NativeHeicEncoderError` on failure
    func encode(rgba: [UInt8], width: Int, height: Int) throws -> Data {
        #if canImport(CoreGraphics) && canImport(ImageIO)
            guard Self.isAvailable() else {
                throw NativeHeicEncoderError.platformNotSupported
            }

            // Validate dimensions
            guard width > 0, height > 0 else {
                throw NativeHeicEncoderError.invalidDimensions
            }

            // Validate RGBA data size
            let expectedSize = width * height * 4
            guard rgba.count == expectedSize else {
                throw NativeHeicEncoderError.invalidRgbaData(expected: expectedSize, actual: rgba.count)
            }

            // HEIC requires even dimensions - round up if odd
            let adjustedWidth = (width + 1) & ~1
            let adjustedHeight = (height + 1) & ~1

            // Prepare RGBA data with potential padding for even dimensions
            let adjustedRgba: [UInt8] = if adjustedWidth != width || adjustedHeight != height {
                padToEvenDimensions(
                    rgba: rgba,
                    originalWidth: width,
                    originalHeight: height,
                    newWidth: adjustedWidth,
                    newHeight: adjustedHeight
                )
            } else {
                rgba
            }

            return try encodeWithImageIO(
                rgba: adjustedRgba,
                width: adjustedWidth,
                height: adjustedHeight
            )
        #else
            throw NativeHeicEncoderError.platformNotSupported
        #endif
    }

    #if canImport(CoreGraphics) && canImport(ImageIO)
        /// Encodes RGBA to HEIC using ImageIO
        private func encodeWithImageIO(rgba: [UInt8], width: Int, height: Int) throws -> Data {
            // Create CGImage from RGBA data
            let bitsPerComponent = 8
            let bitsPerPixel = 32
            let bytesPerRow = width * 4

            // Create data provider from RGBA bytes
            guard let dataProvider = CGDataProvider(data: Data(rgba) as CFData) else {
                throw NativeHeicEncoderError.dataProviderCreationFailed
            }

            // Use sRGB colorspace (DeviceRGB fails silently with HEIC)
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
                throw NativeHeicEncoderError.colorSpaceCreationFailed
            }

            // Create CGImage with straight (non-premultiplied) alpha
            // Input RGBA from PngDecoder/SvgRasterizer is already unpremultiplied
            guard let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bitsPerPixel: bitsPerPixel,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: dataProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            ) else {
                throw NativeHeicEncoderError.cgImageCreationFailed
            }

            // Create mutable data for output
            let mutableData = NSMutableData()

            // Get HEIC UTI
            let heicType: CFString = if #available(macOS 11.0, *) {
                UTType.heic.identifier as CFString
            } else {
                "public.heic" as CFString
            }

            // Create image destination
            guard let destination = CGImageDestinationCreateWithData(
                mutableData,
                heicType,
                1,
                nil
            ) else {
                throw NativeHeicEncoderError.destinationCreationFailed
            }

            // Set encoding options
            // Note: Apple ImageIO does NOT support true lossless HEIC encoding.
            // Setting quality=1.0 gives maximum quality but is still lossy.
            // See: https://developer.apple.com/forums/thread/670094
            var options: [CFString: Any] = [:]

            // For "lossless" mode, use quality=1.0 (maximum quality)
            // For lossy mode, use configured quality
            let normalizedQuality = lossless ? 1.0 : Double(quality) / 100.0
            options[kCGImageDestinationLossyCompressionQuality] = normalizedQuality

            // Add image to destination
            CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

            // Finalize
            guard CGImageDestinationFinalize(destination) else {
                throw NativeHeicEncoderError.finalizationFailed(lossless: lossless, quality: normalizedQuality)
            }

            return mutableData as Data
        }
    #endif

    /// Pads RGBA data to even dimensions by replicating edge pixels
    private func padToEvenDimensions(
        rgba: [UInt8],
        originalWidth: Int,
        originalHeight: Int,
        newWidth: Int,
        newHeight: Int
    ) -> [UInt8] {
        var newRgba = [UInt8](repeating: 0, count: newWidth * newHeight * 4)

        // Copy original rows
        for y in 0 ..< originalHeight {
            let srcOffset = y * originalWidth * 4
            let dstOffset = y * newWidth * 4

            // Copy original row
            for x in 0 ..< originalWidth * 4 {
                newRgba[dstOffset + x] = rgba[srcOffset + x]
            }

            // Replicate last pixel if width was padded
            if newWidth > originalWidth {
                let lastPixelOffset = srcOffset + (originalWidth - 1) * 4
                let padOffset = dstOffset + originalWidth * 4
                for i in 0 ..< 4 {
                    newRgba[padOffset + i] = rgba[lastPixelOffset + i]
                }
            }
        }

        // Replicate last row if height was padded
        if newHeight > originalHeight {
            let lastRowOffset = (originalHeight - 1) * newWidth * 4
            let padRowOffset = originalHeight * newWidth * 4
            for x in 0 ..< newWidth * 4 {
                newRgba[padRowOffset + x] = newRgba[lastRowOffset + x]
            }
        }

        return newRgba
    }

    /// Encodes RGBA pixel data to HEIC file
    /// - Parameters:
    ///   - rgba: Raw RGBA pixel data (4 bytes per pixel)
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - outputURL: Output file URL (.heic)
    /// - Throws: `NativeHeicEncoderError` on encoding failure
    func encode(rgba: [UInt8], width: Int, height: Int, to outputURL: URL) throws {
        let heicData = try encode(rgba: rgba, width: width, height: height)
        try heicData.write(to: outputURL)
    }
}
