@testable import ExFigCLI
import ExFigCore
import Testing

@Suite("FetchWizard")
struct FetchWizardTests {
    // MARK: - WizardPlatform

    @Test("WizardPlatform descriptions match raw values")
    func platformDescriptions() {
        #expect(WizardPlatform.ios.description == "iOS")
        #expect(WizardPlatform.android.description == "Android")
        #expect(WizardPlatform.flutter.description == "Flutter")
        #expect(WizardPlatform.web.description == "Web")
    }

    @Test("WizardPlatform has all 4 cases")
    func platformCases() {
        #expect(WizardPlatform.allCases.count == 4)
    }

    // MARK: - WizardAssetType

    @Test("WizardAssetType descriptions")
    func assetTypeDescriptions() {
        #expect(WizardAssetType.icons.description == "Icons")
        #expect(WizardAssetType.illustrations.description == "Illustrations / Images")
    }

    @Test("WizardAssetType default frame names")
    func assetTypeDefaultFrameNames() {
        #expect(WizardAssetType.icons.defaultFrameName == "Icons")
        #expect(WizardAssetType.illustrations.defaultFrameName == "Illustrations")
    }

    @Test("WizardAssetType default output paths")
    func assetTypeDefaultOutputPaths() {
        #expect(WizardAssetType.icons.defaultOutputPath == "./icons")
        #expect(WizardAssetType.illustrations.defaultOutputPath == "./images")
    }

    // MARK: - PlatformDefaults

    @Test("iOS icons defaults: SVG, no scale, camelCase")
    func iOSIconsDefaults() {
        let defaults = PlatformDefaults.forPlatform(.ios, assetType: .icons)
        #expect(defaults.format == .svg)
        #expect(defaults.scale == nil)
        #expect(defaults.nameStyle == .camelCase)
    }

    @Test("iOS illustrations defaults: PNG, 3x scale, camelCase")
    func iOSIllustrationsDefaults() {
        let defaults = PlatformDefaults.forPlatform(.ios, assetType: .illustrations)
        #expect(defaults.format == .png)
        #expect(defaults.scale == 3.0)
        #expect(defaults.nameStyle == .camelCase)
    }

    @Test("Android icons defaults: SVG, no scale, snake_case")
    func androidIconsDefaults() {
        let defaults = PlatformDefaults.forPlatform(.android, assetType: .icons)
        #expect(defaults.format == .svg)
        #expect(defaults.scale == nil)
        #expect(defaults.nameStyle == .snakeCase)
    }

    @Test("Android illustrations defaults: WebP, 4x scale, snake_case")
    func androidIllustrationsDefaults() {
        let defaults = PlatformDefaults.forPlatform(.android, assetType: .illustrations)
        #expect(defaults.format == .webp)
        #expect(defaults.scale == 4.0)
        #expect(defaults.nameStyle == .snakeCase)
    }

    @Test("Flutter icons defaults: SVG, no scale, snake_case")
    func flutterIconsDefaults() {
        let defaults = PlatformDefaults.forPlatform(.flutter, assetType: .icons)
        #expect(defaults.format == .svg)
        #expect(defaults.scale == nil)
        #expect(defaults.nameStyle == .snakeCase)
    }

    @Test("Flutter illustrations defaults: PNG, 3x scale, snake_case")
    func flutterIllustrationsDefaults() {
        let defaults = PlatformDefaults.forPlatform(.flutter, assetType: .illustrations)
        #expect(defaults.format == .png)
        #expect(defaults.scale == 3.0)
        #expect(defaults.nameStyle == .snakeCase)
    }

    @Test("Web icons defaults: SVG, no scale, kebab-case")
    func webIconsDefaults() {
        let defaults = PlatformDefaults.forPlatform(.web, assetType: .icons)
        #expect(defaults.format == .svg)
        #expect(defaults.scale == nil)
        #expect(defaults.nameStyle == .kebabCase)
    }

    @Test("Web illustrations defaults: SVG, no scale, kebab-case")
    func webIllustrationsDefaults() {
        let defaults = PlatformDefaults.forPlatform(.web, assetType: .illustrations)
        #expect(defaults.format == .svg)
        #expect(defaults.scale == nil)
        #expect(defaults.nameStyle == .kebabCase)
    }

    // MARK: - Sorted Formats

    @Test("sortedFormats puts recommended format first")
    func sortedFormatsRecommendedFirst() {
        let formats = FetchWizard.sortedFormats(recommended: .webp)
        #expect(formats.first == .webp)
        #expect(formats.count == ImageFormat.allCases.count)
    }

    @Test("sortedFormats contains all formats exactly once")
    func sortedFormatsComplete() {
        let formats = FetchWizard.sortedFormats(recommended: .svg)
        #expect(Set(formats) == Set(ImageFormat.allCases))
        #expect(formats.count == ImageFormat.allCases.count)
    }

    // MARK: - ImageFormat CustomStringConvertible

    @Test("ImageFormat descriptions are user-friendly")
    func imageFormatDescriptions() {
        #expect(ImageFormat.png.description == "PNG")
        #expect(ImageFormat.svg.description == "SVG")
        #expect(ImageFormat.jpg.description == "JPG")
        #expect(ImageFormat.pdf.description == "PDF")
        #expect(ImageFormat.webp.description == "WebP")
    }
}
