import ArgumentParser
import ExFigCore
import Foundation

/// Image format for download command
enum ImageFormat: String, ExpressibleByArgument, CaseIterable {
    case png
    case svg
    case jpg
    case pdf
    case webp

    static var allValueStrings: [String] {
        allCases.map(\.rawValue)
    }
}

/// WebP encoding type for download command
enum WebpEncoding: String, ExpressibleByArgument, CaseIterable {
    case lossy
    case lossless
}

/// Make NameStyle available as CLI argument
extension NameStyle: ExpressibleByArgument {
    public init?(argument: String) {
        switch argument {
        case "camelCase":
            self = .camelCase
        case "snake_case", "snakeCase":
            self = .snakeCase
        case "PascalCase", "pascalCase":
            self = .pascalCase
        case "kebab-case", "kebabCase":
            self = .kebabCase
        case "SCREAMING_SNAKE_CASE", "screamingSnakeCase":
            self = .screamingSnakeCase
        default:
            return nil
        }
    }

    public static var allValueStrings: [String] {
        ["camelCase", "snake_case", "PascalCase", "kebab-case", "SCREAMING_SNAKE_CASE"]
    }
}

/// Design source for fetch command.
enum FetchSource: String, ExpressibleByArgument, CaseIterable {
    case figma
    case penpot
}

/// CLI options for the download command.
/// All required parameters for downloading images from Figma or Penpot without a config file.
struct DownloadOptions: ParsableArguments {
    // MARK: - Source Options

    @Option(name: .long, help: "Design source: figma, penpot. Default: figma")
    var source: FetchSource?

    @Option(
        name: [.customLong("penpot-base-url")],
        help: "Penpot instance base URL (default: design.penpot.app)"
    )
    var penpotBaseURL: String?

    // MARK: - Required Options

    @Option(
        name: [.customLong("file-id"), .customShort("f")],
        help: "File ID (Figma file key or Penpot file UUID)"
    )
    var fileId: String?

    @Option(
        name: [.customLong("frame"), .customShort("r")],
        help: "Name of the Figma frame containing images"
    )
    var frameName: String?

    @Option(name: [.customLong("page"), .customShort("p")], help: "Filter by Figma page name.")
    var pageName: String?

    @Option(
        name: [.customLong("output"), .customShort("o")],
        help: "Output directory for downloaded images"
    )
    var outputPath: String?

    // MARK: - Format Options

    @Option(
        name: .long,
        help: "Image format: \(ImageFormat.allValueStrings.joined(separator: ", ")). Default: png"
    )
    var format: ImageFormat?

    @Option(
        name: .long,
        help: "Scale factor (0.01-4.0). Default: 3 for PNG, ignored for vector formats"
    )
    var scale: Double?

    // MARK: - Filtering and Naming Options

    @Option(
        name: .long,
        help: "Filter pattern (e.g., 'icon/*' or 'logo, banner')"
    )
    var filter: String?

    @Option(
        name: [.customLong("name-style")],
        help: "Name style: \(NameStyle.allValueStrings.joined(separator: ", "))"
    )
    var nameStyle: NameStyle?

    @Option(
        name: [.customLong("name-validate-regexp")],
        help: "RegExp pattern for name validation"
    )
    var nameValidateRegexp: String?

    @Option(
        name: [.customLong("name-replace-regexp")],
        help: "RegExp pattern for name replacement (supports $1, $2, etc.)"
    )
    var nameReplaceRegexp: String?

    // MARK: - Dark Mode Options

    @Option(
        name: [.customLong("dark-mode-suffix")],
        help: "Suffix for dark mode variants (e.g., '_dark'). Enables single-file dark mode extraction"
    )
    var darkModeSuffix: String?

    // MARK: - WebP Options

    @Option(
        name: [.customLong("webp-encoding")],
        help: "WebP encoding: lossy or lossless. Default: lossy"
    )
    var webpEncoding: WebpEncoding = .lossy

    @Option(
        name: [.customLong("webp-quality")],
        help: "WebP quality (0-100). Default: 80. Only for lossy encoding"
    )
    var webpQuality: Int = 80

    // MARK: - Connection Options

    @Option(
        name: .long,
        help: "Figma API request timeout in seconds. Default: 30"
    )
    var timeout: Int = 30

    // MARK: - Validation

    mutating func validate() throws {
        // Validate scale range
        if let scale {
            guard scale >= 0.01, scale <= 4.0 else {
                throw ValidationError("Scale must be between 0.01 and 4.0")
            }
        }

        // Validate WebP quality
        guard webpQuality >= 0, webpQuality <= 100 else {
            throw ValidationError("WebP quality must be between 0 and 100")
        }

        // Validate timeout
        guard timeout > 0 else {
            throw ValidationError("Timeout must be positive")
        }
    }

    // MARK: - Computed Properties

    /// Returns the effective format, defaulting to `.png` when not explicitly set.
    var effectiveFormat: ImageFormat {
        format ?? .png
    }

    /// Returns the effective scale based on format.
    /// For PNG: defaults to 3 if not specified.
    /// For vector formats (SVG, PDF): scale is ignored.
    var effectiveScale: Double {
        switch effectiveFormat {
        case .png, .jpg, .webp:
            scale ?? 3.0
        case .svg, .pdf:
            1.0 // Ignored for vector formats
        }
    }

    /// Returns true if format is a vector format (scale is ignored)
    var isVectorFormat: Bool {
        effectiveFormat == .svg || effectiveFormat == .pdf
    }

    /// Returns the Figma access token from environment
    var accessToken: String? {
        ProcessInfo.processInfo.environment["FIGMA_PERSONAL_TOKEN"]
    }

    /// Returns the output directory URL (nil if outputPath not set)
    var outputURL: URL? {
        guard let outputPath else { return nil }
        return URL(fileURLWithPath: outputPath, isDirectory: true)
    }
}

// MARK: - ImageFormat Display

extension ImageFormat: CustomStringConvertible {
    var description: String {
        switch self {
        case .png: "PNG"
        case .svg: "SVG"
        case .jpg: "JPG"
        case .pdf: "PDF"
        case .webp: "WebP"
        }
    }
}
