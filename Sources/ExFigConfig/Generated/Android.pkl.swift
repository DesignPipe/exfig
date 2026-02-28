// Code generated from Pkl module `Android`. DO NOT EDIT.
import PklSwift

public enum Android {}

extension Android {
    /// Compose icon generation format.
    /// - `resourceReference`: Generates extension functions using painterResource(R.drawable.xxx)
    /// - `imageVector`: Generates ImageVector code directly from SVG data
    public enum ComposeIconFormat: String, CaseIterable, CodingKeyRepresentable, Decodable, Hashable, Sendable {
        case resourceReference = "resourceReference"
        case imageVector = "imageVector"
    }

    /// Android image format.
    public enum ImageFormat: String, CaseIterable, CodingKeyRepresentable, Decodable, Hashable, Sendable {
        case svg = "svg"
        case png = "png"
        case webp = "webp"
    }

    /// Android platform configuration for ExFig.
    public struct Module: PklRegisteredType, Decodable, Hashable, Sendable {
        public static let registeredIdentifier: String = "Android"

        public init() {}
    }

    /// Name transformation for theme attributes.
    public struct NameTransform: PklRegisteredType, Decodable, Hashable, Sendable {
        public static let registeredIdentifier: String = "Android#NameTransform"

        /// Target case style for attribute names.
        public var style: Common.NameStyle?

        /// Prefix to add to attribute names.
        public var prefix: String?

        /// Prefixes to strip from color names before transformation.
        public var stripPrefixes: [String]?

        public init(style: Common.NameStyle?, prefix: String?, stripPrefixes: [String]?) {
            self.style = style
            self.prefix = prefix
            self.stripPrefixes = stripPrefixes
        }
    }

    /// Theme attributes configuration for generating attrs.xml and styles.xml.
    public struct ThemeAttributes: PklRegisteredType, Decodable, Hashable, Sendable {
        public static let registeredIdentifier: String = "Android#ThemeAttributes"

        /// Whether theme attributes generation is enabled.
        public var enabled: Bool?

        /// Path to attrs.xml relative to mainRes.
        public var attrsFile: String?

        /// Path to styles.xml relative to mainRes.
        public var stylesFile: String?

        /// Path to styles-night.xml relative to mainRes.
        public var stylesNightFile: String?

        /// Theme name used in markers (e.g., "Theme.MyApp.Main").
        public var themeName: String

        /// Custom marker start text.
        public var markerStart: String?

        /// Custom marker end text.
        public var markerEnd: String?

        /// Name transformation configuration.
        public var nameTransform: NameTransform?

        /// If true, create file with markers if missing.
        public var autoCreateMarkers: Bool?

        public init(
            enabled: Bool?,
            attrsFile: String?,
            stylesFile: String?,
            stylesNightFile: String?,
            themeName: String,
            markerStart: String?,
            markerEnd: String?,
            nameTransform: NameTransform?,
            autoCreateMarkers: Bool?
        ) {
            self.enabled = enabled
            self.attrsFile = attrsFile
            self.stylesFile = stylesFile
            self.stylesNightFile = stylesNightFile
            self.themeName = themeName
            self.markerStart = markerStart
            self.markerEnd = markerEnd
            self.nameTransform = nameTransform
            self.autoCreateMarkers = autoCreateMarkers
        }
    }

    /// Android colors entry configuration.
    public struct ColorsEntry: Common.VariablesSource {
        public static let registeredIdentifier: String = "Android#ColorsEntry"

        /// Override path to main res directory for this entry.
        /// When set, overrides `AndroidConfig.mainRes`.
        public var mainRes: String?

        /// Override path to main src directory for this entry.
        /// When set, overrides `AndroidConfig.mainSrc`.
        public var mainSrc: String?

        /// Override path to custom Jinja2 templates for this entry.
        /// When set, overrides `AndroidConfig.templatesPath`.
        public var templatesPath: String?

        /// Output filename for colors XML. Default: figma_colors.xml
        public var xmlOutputFileName: String?

        /// Skip XML generation entirely. Useful for Compose-only projects.
        public var xmlDisabled: Bool?

        /// Package name for generated Compose colors.
        public var composePackageName: String?

        /// Path to generate Compose Color Kotlin file.
        public var colorKotlin: String?

        /// Theme attributes configuration.
        public var themeAttributes: ThemeAttributes?

        /// Local .tokens.json file source (bypasses Figma API when set).
        public var tokensFile: Common.TokensFile?

        /// Figma file ID containing the variables.
        public var tokensFileId: String?

        /// Name of the variable collection.
        public var tokensCollectionName: String?

        /// Mode name for light theme.
        public var lightModeName: String?

        /// Mode name for dark theme.
        public var darkModeName: String?

        /// Mode name for light high contrast theme.
        public var lightHCModeName: String?

        /// Mode name for dark high contrast theme.
        public var darkHCModeName: String?

        /// Mode name for primitives/aliases layer.
        public var primitivesModeName: String?

        /// Regex pattern for validating/capturing names.
        public var nameValidateRegexp: String?

        /// Replacement pattern using captured groups.
        public var nameReplaceRegexp: String?

        public init(
            mainRes: String?,
            mainSrc: String?,
            templatesPath: String?,
            xmlOutputFileName: String?,
            xmlDisabled: Bool?,
            composePackageName: String?,
            colorKotlin: String?,
            themeAttributes: ThemeAttributes?,
            tokensFile: Common.TokensFile?,
            tokensFileId: String?,
            tokensCollectionName: String?,
            lightModeName: String?,
            darkModeName: String?,
            lightHCModeName: String?,
            darkHCModeName: String?,
            primitivesModeName: String?,
            nameValidateRegexp: String?,
            nameReplaceRegexp: String?
        ) {
            self.mainRes = mainRes
            self.mainSrc = mainSrc
            self.templatesPath = templatesPath
            self.xmlOutputFileName = xmlOutputFileName
            self.xmlDisabled = xmlDisabled
            self.composePackageName = composePackageName
            self.colorKotlin = colorKotlin
            self.themeAttributes = themeAttributes
            self.tokensFile = tokensFile
            self.tokensFileId = tokensFileId
            self.tokensCollectionName = tokensCollectionName
            self.lightModeName = lightModeName
            self.darkModeName = darkModeName
            self.lightHCModeName = lightHCModeName
            self.darkHCModeName = darkHCModeName
            self.primitivesModeName = primitivesModeName
            self.nameValidateRegexp = nameValidateRegexp
            self.nameReplaceRegexp = nameReplaceRegexp
        }
    }

    /// Android icons entry configuration.
    public struct IconsEntry: Common.FrameSource {
        public static let registeredIdentifier: String = "Android#IconsEntry"

        /// Override path to main res directory for this entry.
        /// When set, overrides `AndroidConfig.mainRes`.
        public var mainRes: String?

        /// Override path to custom Jinja2 templates for this entry.
        /// When set, overrides `AndroidConfig.templatesPath`.
        public var templatesPath: String?

        /// Output directory for vector drawables.
        public var output: String

        /// Package name for generated Compose icons.
        public var composePackageName: String?

        /// Format for Compose icon generation.
        public var composeFormat: ComposeIconFormat?

        /// Extension target for ImageVector (e.g., "com.example.app.ui.AppIcons").
        public var composeExtensionTarget: String?

        /// Naming style for icon names.
        public var nameStyle: Common.NameStyle?

        /// Coordinate precision for pathData (1-6).
        public var pathPrecision: Int?

        /// If true, exit with error when pathData exceeds 32,767 bytes.
        public var strictPathValidation: Bool?

        /// Path to generate Figma Code Connect Kotlin file for Jetpack Compose.
        public var codeConnectKotlin: String?

        /// Figma frame name to export from.
        public var figmaFrameName: String?

        /// Figma page name to filter components by.
        /// When set, only components from this specific page are exported.
        /// Useful when multiple pages have frames with the same name.
        public var figmaPageName: String?

        /// Override Figma file ID for this specific entry.
        /// When set, overrides the global `figma.lightFileId` for loading data.
        public var figmaFileId: String?

        /// Figma component property name for RTL variant detection.
        /// When set, components in a COMPONENT_SET with this variant property
        /// have their RTL=Off variant exported with RTL metadata (isRTL flag).
        /// RTL=On variants are automatically skipped — the base variant is
        /// mirrored at runtime by the platform (iOS languageDirection, Android autoMirrored).
        /// Set to null to disable variant-based RTL detection.
        public var rtlProperty: String?

        /// Regex pattern for validating/capturing names.
        public var nameValidateRegexp: String?

        /// Replacement pattern using captured groups.
        public var nameReplaceRegexp: String?

        public init(
            mainRes: String?,
            templatesPath: String?,
            output: String,
            composePackageName: String?,
            composeFormat: ComposeIconFormat?,
            composeExtensionTarget: String?,
            nameStyle: Common.NameStyle?,
            pathPrecision: Int?,
            strictPathValidation: Bool?,
            codeConnectKotlin: String?,
            figmaFrameName: String?,
            figmaPageName: String?,
            figmaFileId: String?,
            rtlProperty: String?,
            nameValidateRegexp: String?,
            nameReplaceRegexp: String?
        ) {
            self.mainRes = mainRes
            self.templatesPath = templatesPath
            self.output = output
            self.composePackageName = composePackageName
            self.composeFormat = composeFormat
            self.composeExtensionTarget = composeExtensionTarget
            self.nameStyle = nameStyle
            self.pathPrecision = pathPrecision
            self.strictPathValidation = strictPathValidation
            self.codeConnectKotlin = codeConnectKotlin
            self.figmaFrameName = figmaFrameName
            self.figmaPageName = figmaPageName
            self.figmaFileId = figmaFileId
            self.rtlProperty = rtlProperty
            self.nameValidateRegexp = nameValidateRegexp
            self.nameReplaceRegexp = nameReplaceRegexp
        }
    }

    /// Android images entry configuration.
    public struct ImagesEntry: Common.FrameSource {
        public static let registeredIdentifier: String = "Android#ImagesEntry"

        /// Override path to main res directory for this entry.
        /// When set, overrides `AndroidConfig.mainRes`.
        public var mainRes: String?

        /// Override path to custom Jinja2 templates for this entry.
        /// When set, overrides `AndroidConfig.templatesPath`.
        public var templatesPath: String?

        /// Scale factors to generate (e.g., [1, 1.5, 2, 3, 4]).
        public var scales: [Float64]?

        /// Output directory for images.
        public var output: String

        /// Output format for images.
        public var format: ImageFormat

        /// WebP encoding options.
        public var webpOptions: Common.WebpOptions?

        /// Source format for fetching from Figma API.
        public var sourceFormat: Common.SourceFormat?

        /// Naming style for generated image names.
        public var nameStyle: Common.NameStyle?

        /// Path to generate Figma Code Connect Kotlin file for Jetpack Compose.
        public var codeConnectKotlin: String?

        /// Figma frame name to export from.
        public var figmaFrameName: String?

        /// Figma page name to filter components by.
        /// When set, only components from this specific page are exported.
        /// Useful when multiple pages have frames with the same name.
        public var figmaPageName: String?

        /// Override Figma file ID for this specific entry.
        /// When set, overrides the global `figma.lightFileId` for loading data.
        public var figmaFileId: String?

        /// Figma component property name for RTL variant detection.
        /// When set, components in a COMPONENT_SET with this variant property
        /// have their RTL=Off variant exported with RTL metadata (isRTL flag).
        /// RTL=On variants are automatically skipped — the base variant is
        /// mirrored at runtime by the platform (iOS languageDirection, Android autoMirrored).
        /// Set to null to disable variant-based RTL detection.
        public var rtlProperty: String?

        /// Regex pattern for validating/capturing names.
        public var nameValidateRegexp: String?

        /// Replacement pattern using captured groups.
        public var nameReplaceRegexp: String?

        public init(
            mainRes: String?,
            templatesPath: String?,
            scales: [Float64]?,
            output: String,
            format: ImageFormat,
            webpOptions: Common.WebpOptions?,
            sourceFormat: Common.SourceFormat?,
            nameStyle: Common.NameStyle?,
            codeConnectKotlin: String?,
            figmaFrameName: String?,
            figmaPageName: String?,
            figmaFileId: String?,
            rtlProperty: String?,
            nameValidateRegexp: String?,
            nameReplaceRegexp: String?
        ) {
            self.mainRes = mainRes
            self.templatesPath = templatesPath
            self.scales = scales
            self.output = output
            self.format = format
            self.webpOptions = webpOptions
            self.sourceFormat = sourceFormat
            self.nameStyle = nameStyle
            self.codeConnectKotlin = codeConnectKotlin
            self.figmaFrameName = figmaFrameName
            self.figmaPageName = figmaPageName
            self.figmaFileId = figmaFileId
            self.rtlProperty = rtlProperty
            self.nameValidateRegexp = nameValidateRegexp
            self.nameReplaceRegexp = nameReplaceRegexp
        }
    }

    /// Android typography configuration.
    public struct Typography: PklRegisteredType, Decodable, Hashable, Sendable {
        public static let registeredIdentifier: String = "Android#Typography"

        /// Figma file ID override for typography (optional).
        public var fileId: String?

        /// Regex pattern for validating/capturing text style names.
        public var nameValidateRegexp: String?

        /// Replacement pattern for text style names.
        public var nameReplaceRegexp: String?

        /// Naming style for generated type names.
        public var nameStyle: Common.NameStyle

        /// Package name for generated Compose typography.
        public var composePackageName: String?

        public init(
            fileId: String?,
            nameValidateRegexp: String?,
            nameReplaceRegexp: String?,
            nameStyle: Common.NameStyle,
            composePackageName: String?
        ) {
            self.fileId = fileId
            self.nameValidateRegexp = nameValidateRegexp
            self.nameReplaceRegexp = nameReplaceRegexp
            self.nameStyle = nameStyle
            self.composePackageName = composePackageName
        }
    }

    /// Root Android platform configuration.
    public struct AndroidConfig: PklRegisteredType, Decodable, Hashable, Sendable {
        public static let registeredIdentifier: String = "Android#AndroidConfig"

        /// Path to main res directory.
        public var mainRes: String

        /// Resource package name (R class package).
        public var resourcePackage: String?

        /// Path to main src directory for Kotlin generation.
        public var mainSrc: String?

        /// Path to custom Jinja2 templates.
        public var templatesPath: String?

        /// Colors configuration entries.
        public var colors: [ColorsEntry]?

        /// Icons configuration entries.
        public var icons: [IconsEntry]?

        /// Images configuration entries.
        public var images: [ImagesEntry]?

        /// Typography configuration.
        public var typography: Typography?

        public init(
            mainRes: String,
            resourcePackage: String?,
            mainSrc: String?,
            templatesPath: String?,
            colors: [ColorsEntry]?,
            icons: [IconsEntry]?,
            images: [ImagesEntry]?,
            typography: Typography?
        ) {
            self.mainRes = mainRes
            self.resourcePackage = resourcePackage
            self.mainSrc = mainSrc
            self.templatesPath = templatesPath
            self.colors = colors
            self.icons = icons
            self.images = images
            self.typography = typography
        }
    }

    /// Load the Pkl module at the given source and evaluate it into `Android.Module`.
    ///
    /// - Parameter source: The source of the Pkl module.
    public static func loadFrom(source: ModuleSource) async throws -> Android.Module {
        try await PklSwift.withEvaluator { evaluator in
            try await loadFrom(evaluator: evaluator, source: source)
        }
    }

    /// Load the Pkl module at the given source and evaluate it with the given evaluator into
    /// `Android.Module`.
    ///
    /// - Parameter evaluator: The evaluator to use for evaluation.
    /// - Parameter source: The module to evaluate.
    public static func loadFrom(
        evaluator: PklSwift.Evaluator,
        source: PklSwift.ModuleSource
    ) async throws -> Android.Module {
        try await evaluator.evaluateModule(source: source, as: Module.self)
    }
}
