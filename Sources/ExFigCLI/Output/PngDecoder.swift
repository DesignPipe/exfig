import Foundation

#if canImport(CoreGraphics)
    import CoreGraphics
#endif

#if canImport(ImageIO)
    import ImageIO
#endif

#if canImport(LibPNG)
    import LibPNG
#endif

/// Errors that can occur during PNG decoding
enum PngDecoderError: LocalizedError, Equatable {
    case invalidFormat
    case fileNotFound(path: String)
    case decodingFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            "Invalid PNG format"
        case let .fileNotFound(path):
            "PNG file not found: \(path)"
        case let .decodingFailed(reason):
            "PNG decoding failed: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidFormat:
            "Ensure the file is a valid PNG image"
        case .fileNotFound:
            "Check that the file path exists"
        case .decodingFailed:
            "Re-export the image from Figma"
        }
    }
}

/// Result of PNG decoding containing RGBA pixel data
struct DecodedPng {
    let width: Int
    let height: Int
    let rgba: [UInt8]

    /// Total number of bytes (should equal width * height * 4)
    var byteCount: Int {
        rgba.count
    }
}

/// Decodes PNG images to raw RGBA pixel data
///
/// Uses platform-native APIs for reliable cross-platform PNG decoding:
/// - macOS/iOS: CoreGraphics/ImageIO
/// - Linux: libpng (via libwebp transitive dependency)
struct PngDecoder {
    /// Decodes a PNG file to RGBA pixel data
    /// - Parameter url: Path to PNG file
    /// - Returns: Decoded PNG with width, height, and RGBA bytes
    /// - Throws: `PngDecoderError` on failure
    func decode(file url: URL) throws -> DecodedPng {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PngDecoderError.fileNotFound(path: url.path)
        }

        let data = try Data(contentsOf: url)
        return try decode(data: data)
    }

    /// Decodes PNG data to RGBA pixel data
    /// - Parameter data: PNG file data
    /// - Returns: Decoded PNG with width, height, and RGBA bytes
    /// - Throws: `PngDecoderError` on failure
    func decode(data: Data) throws -> DecodedPng {
        // Validate PNG magic bytes
        guard data.count >= 8 else {
            throw PngDecoderError.invalidFormat
        }

        let pngMagic: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        let header = [UInt8](data.prefix(8))
        guard header == pngMagic else {
            throw PngDecoderError.invalidFormat
        }

        #if canImport(CoreGraphics) && canImport(ImageIO)
            return try decodeWithCoreGraphics(data: data)
        #else
            return try decodeWithLibpng(data: data)
        #endif
    }

    #if canImport(CoreGraphics) && canImport(ImageIO)
        /// Decodes PNG using CoreGraphics/ImageIO (Apple platforms)
        private func decodeWithCoreGraphics(data: Data) throws -> DecodedPng {
            guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
                throw PngDecoderError.decodingFailed(reason: "Failed to create image source")
            }

            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                throw PngDecoderError.decodingFailed(reason: "Failed to create CGImage")
            }

            let width = cgImage.width
            let height = cgImage.height
            let bytesPerRow = width * 4

            // Create RGBA bitmap context
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
                throw PngDecoderError.decodingFailed(reason: "Failed to create color space")
            }

            var rgba = [UInt8](repeating: 0, count: width * height * 4)

            guard let context = CGContext(
                data: &rgba,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else {
                throw PngDecoderError.decodingFailed(reason: "Failed to create bitmap context")
            }

            // Draw image into context to get RGBA data
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

            // Unpremultiply alpha for correct color values
            unpremultiplyAlpha(&rgba)

            return DecodedPng(width: width, height: height, rgba: rgba)
        }

        /// Unpremultiplies alpha values to get correct RGB values
        private func unpremultiplyAlpha(_ rgba: inout [UInt8]) {
            let pixelCount = rgba.count / 4
            for i in 0 ..< pixelCount {
                let offset = i * 4
                let alpha = rgba[offset + 3]

                if alpha > 0, alpha < 255 {
                    let alphaFloat = Float(alpha) / 255.0
                    rgba[offset] = UInt8(min(255, Float(rgba[offset]) / alphaFloat))
                    rgba[offset + 1] = UInt8(min(255, Float(rgba[offset + 1]) / alphaFloat))
                    rgba[offset + 2] = UInt8(min(255, Float(rgba[offset + 2]) / alphaFloat))
                }
            }
        }
    #else
        /// libpng format constants (not available as Swift constants due to macro limitations)
        /// PNG_FORMAT_FLAG_COLOR = 2, PNG_FORMAT_FLAG_ALPHA = 4
        /// PNG_FORMAT_RGBA = PNG_FORMAT_FLAG_COLOR | PNG_FORMAT_FLAG_ALPHA = 6
        private static let pngFormatRGBA: UInt32 = 6

        /// Decodes PNG using libpng (Linux)
        private func decodeWithLibpng(data: Data) throws -> DecodedPng {
            // Write data to temporary file (libpng simplified API reads from file)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("png-decode-\(UUID().uuidString).png")

            defer {
                try? FileManager.default.removeItem(at: tempURL)
            }

            try data.write(to: tempURL)

            var image = png_image()
            image.version = UInt32(PNG_IMAGE_VERSION)

            // Read PNG header
            let beginSuccess = tempURL.path.withCString { pathPtr in
                png_image_begin_read_from_file(&image, pathPtr) != 0
            }

            guard beginSuccess else {
                throw PngDecoderError.decodingFailed(reason: "Failed to read PNG header")
            }

            // Set format to RGBA
            image.format = Self.pngFormatRGBA

            let width = Int(image.width)
            let height = Int(image.height)
            // PNG_IMAGE_SIZE for RGBA = width * height * 4 (4 bytes per pixel)
            let bufferSize = width * height * 4

            var buffer = [UInt8](repeating: 0, count: bufferSize)

            // Read pixel data
            let readSuccess = buffer.withUnsafeMutableBytes { bufferPtr -> Int32 in
                png_image_finish_read(&image, nil, bufferPtr.baseAddress, 0, nil)
            }

            guard readSuccess != 0 else {
                png_image_free(&image)
                throw PngDecoderError.decodingFailed(reason: "Failed to decode PNG pixels")
            }

            // Note: png_image_finish_read already frees the image on success
            // Do NOT call png_image_free here to avoid double-free

            return DecodedPng(width: width, height: height, rgba: buffer)
        }
    #endif
}
