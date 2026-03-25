import Foundation

#if canImport(CoreGraphics)
    import CoreGraphics
#endif

#if canImport(ImageIO)
    import ImageIO
    import UniformTypeIdentifiers
#endif

#if canImport(LibPNG)
    import LibPNG
#endif

/// Errors that can occur during PNG encoding
enum NativePngEncoderError: LocalizedError, Equatable {
    case encodingFailed(reason: String)
    case invalidDimensions

    var errorDescription: String? {
        switch self {
        case let .encodingFailed(reason):
            "PNG encoding failed: \(reason)"
        case .invalidDimensions:
            "Invalid image dimensions"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .encodingFailed:
            "Try re-exporting the source image"
        case .invalidDimensions:
            "Ensure width and height are positive"
        }
    }
}

/// Encodes RGBA pixel data to PNG format
///
/// Uses platform-native APIs for reliable cross-platform PNG encoding:
/// - macOS/iOS: CoreGraphics/ImageIO
/// - Linux: libpng
struct NativePngEncoder {
    /// Encodes RGBA pixel data to PNG
    /// - Parameters:
    ///   - rgba: RGBA pixel data (4 bytes per pixel)
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    /// - Returns: PNG encoded data
    /// - Throws: `NativePngEncoderError` on failure
    func encode(rgba: [UInt8], width: Int, height: Int) throws -> Data {
        guard width > 0, height > 0 else {
            throw NativePngEncoderError.invalidDimensions
        }

        guard rgba.count == width * height * 4 else {
            throw NativePngEncoderError.encodingFailed(
                reason: "RGBA buffer size \(rgba.count) doesn't match dimensions \(width)x\(height)"
            )
        }

        #if canImport(CoreGraphics) && canImport(ImageIO)
            return try encodeWithCoreGraphics(rgba: rgba, width: width, height: height)
        #else
            return try encodeWithLibpng(rgba: rgba, width: width, height: height)
        #endif
    }

    #if canImport(CoreGraphics) && canImport(ImageIO)
        /// Encodes PNG using CoreGraphics/ImageIO (Apple platforms)
        private func encodeWithCoreGraphics(rgba: [UInt8], width: Int, height: Int) throws -> Data {
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
                throw NativePngEncoderError.encodingFailed(reason: "Failed to create color space")
            }

            let bytesPerRow = width * 4
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

            // Premultiply alpha for CoreGraphics (it expects premultiplied)
            var premultiplied = premultiplyAlpha(rgba)

            guard let context = CGContext(
                data: &premultiplied,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                throw NativePngEncoderError.encodingFailed(reason: "Failed to create bitmap context")
            }

            guard let cgImage = context.makeImage() else {
                throw NativePngEncoderError.encodingFailed(reason: "Failed to create CGImage")
            }

            let mutableData = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                mutableData as CFMutableData,
                UTType.png.identifier as CFString,
                1,
                nil
            ) else {
                throw NativePngEncoderError.encodingFailed(reason: "Failed to create image destination")
            }

            CGImageDestinationAddImage(destination, cgImage, nil)

            guard CGImageDestinationFinalize(destination) else {
                throw NativePngEncoderError.encodingFailed(reason: "Failed to finalize PNG")
            }

            return mutableData as Data
        }

        /// Premultiplies alpha values for CoreGraphics
        private func premultiplyAlpha(_ rgba: [UInt8]) -> [UInt8] {
            var result = rgba
            let pixelCount = rgba.count / 4
            for i in 0 ..< pixelCount {
                let offset = i * 4
                let alpha = rgba[offset + 3]

                if alpha > 0, alpha < 255 {
                    let alphaFloat = Float(alpha) / 255.0
                    result[offset] = UInt8(Float(rgba[offset]) * alphaFloat)
                    result[offset + 1] = UInt8(Float(rgba[offset + 1]) * alphaFloat)
                    result[offset + 2] = UInt8(Float(rgba[offset + 2]) * alphaFloat)
                } else if alpha == 0 {
                    result[offset] = 0
                    result[offset + 1] = 0
                    result[offset + 2] = 0
                }
            }
            return result
        }
    #else
        /// libpng format constants
        private static let pngFormatRGBA: UInt32 = 6

        /// Encodes PNG using libpng (Linux)
        private func encodeWithLibpng(rgba: [UInt8], width: Int, height: Int) throws -> Data {
            var image = png_image()
            image.version = UInt32(PNG_IMAGE_VERSION)
            image.width = UInt32(width)
            image.height = UInt32(height)
            image.format = Self.pngFormatRGBA

            // First call to get required buffer size
            var bufferSize = 0
            let sizeSuccess = rgba.withUnsafeBytes { rgbaPtr -> Int32 in
                png_image_write_to_memory(
                    &image,
                    nil,
                    &bufferSize,
                    0,
                    rgbaPtr.baseAddress,
                    0,
                    nil
                )
            }

            guard sizeSuccess != 0, bufferSize > 0 else {
                throw NativePngEncoderError.encodingFailed(reason: "Failed to calculate PNG size")
            }

            // Allocate buffer and write PNG
            var pngBuffer = [UInt8](repeating: 0, count: bufferSize)
            let writeSuccess = rgba.withUnsafeBytes { rgbaPtr -> Int32 in
                pngBuffer.withUnsafeMutableBytes { bufferPtr -> Int32 in
                    png_image_write_to_memory(
                        &image,
                        bufferPtr.baseAddress,
                        &bufferSize,
                        0,
                        rgbaPtr.baseAddress,
                        0,
                        nil
                    )
                }
            }

            guard writeSuccess != 0 else {
                throw NativePngEncoderError.encodingFailed(reason: "Failed to encode PNG")
            }

            return Data(pngBuffer.prefix(bufferSize))
        }
    #endif
}
