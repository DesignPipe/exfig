// Code generated from Pkl module `iOS`. DO NOT EDIT.
import PklSwift

public enum iOS {}

extension iOS {
    /// HEIC encoding mode.
    public enum HeicEncoding: String, CaseIterable, CodingKeyRepresentable, Decodable, Hashable, Sendable {
        case lossy = "lossy"
        case lossless = "lossless"
    }

    /// Xcode asset catalog render mode.
    public enum XcodeRenderMode: String, CaseIterable, CodingKeyRepresentable, Decodable, Hashable, Sendable {
        case `default` = "default"
        case original = "original"
        case template = "template"
    }

    /// Output format for iOS images in asset catalogs.
    /// - `png`: Standard PNG format (default, maximum compatibility)
    /// - `heic`: HEIC format (~40-50% smaller, iOS 12+, macOS only for encoding)
    public enum ImageOutputFormat: String, CaseIterable, CodingKeyRepresentable, Decodable, Hashable, Sendable {
        case png = "png"
        case heic = "heic"
    }

    /// iOS platform configuration for ExFig.
    public struct Module: PklRegisteredType, Decodable, Hashable, Sendable {
        public static let registeredIdentifier: String = "iOS"

        public init() {}
    }

    /// HEIC encoding options for iOS images.
    public struct HeicOptions: PklRegisteredType, Decodable, Hashable, Sendable {
        public static let registeredIdentifier: String = "iOS#HeicOptions"

        /// Encoding mode: lossy (default) or lossless.
        public var encoding: HeicEncoding?

        /// Quality for lossy encoding (0-100). Default: 90.
        public var quality: Int?

        public init(encoding: HeicEncoding?, quality: Int?) {
            self.encoding = encoding
            self.quality = quality
        }
    }

    /// iOS colors entry configuration.
    /// Can include inline source or use common.variablesColors.
    public struct ColorsEntry: Common.VariablesSource {
        public static let registeredIdentifier: String = "iOS#ColorsEntry"

        /// Use Color Assets (.xcassets) instead of code-only colors.
        public var useColorAssets: Bool

        /// Path to .xcassets folder for color assets.
        public var assetsFolder: String?

        /// Naming style for generated color names.
        public var nameStyle: Common.NameStyle

        /// Group colors using namespace in asset catalog.
        public var groupUsingNamespace: Bool?

        /// Set "provides-namespace" on the assetsFolder in asset catalog.
        /// When true, colors are accessed with folder prefix: "FolderName/colorName".
        public var assetsFolderProvidesNamespace: Bool?

        /// Path to generate UIColor extension Swift file.
        public var colorSwift: String?

        /// Path to generate SwiftUI Color extension Swift file.
        public var swiftuiColorSwift: String?

        /// Override path to .xcassets folder for this entry.
        /// When set, overrides `iOSConfig.xcassetsPath`.
        public var xcassetsPath: String?

        /// Override path to custom Jinja2 templates for this entry.
        /// When set, overrides `iOSConfig.templatesPath`.
        public var templatesPath: String?

        /// Sync generated code names back to Figma Variables codeSyntax.iOS field.
        public var syncCodeSyntax: Bool?

        /// Template for codeSyntax.iOS. Use {name} for variable name.
        /// Example: "Color.{name}" → "Color.backgroundAccent"
        public var codeSyntaxTemplate: String?

        /// Design source kind override. When null, auto-detected:
        /// - If `penpotSource` is set → "penpot"
        /// - If `tokensFile` is set → "tokens-file"
        /// - Otherwise → "figma"
        public var sourceKind: Common.SourceKind?

        /// Penpot source configuration (bypasses Figma API when set).
        public var penpotSource: Common.PenpotSource?

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
            useColorAssets: Bool,
            assetsFolder: String?,
            nameStyle: Common.NameStyle,
            groupUsingNamespace: Bool?,
            assetsFolderProvidesNamespace: Bool?,
            colorSwift: String?,
            swiftuiColorSwift: String?,
            xcassetsPath: String?,
            templatesPath: String?,
            syncCodeSyntax: Bool?,
            codeSyntaxTemplate: String?,
            sourceKind: Common.SourceKind?,
            penpotSource: Common.PenpotSource?,
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
            self.useColorAssets = useColorAssets
            self.assetsFolder = assetsFolder
            self.nameStyle = nameStyle
            self.groupUsingNamespace = groupUsingNamespace
            self.assetsFolderProvidesNamespace = assetsFolderProvidesNamespace
            self.colorSwift = colorSwift
            self.swiftuiColorSwift = swiftuiColorSwift
            self.xcassetsPath = xcassetsPath
            self.templatesPath = templatesPath
            self.syncCodeSyntax = syncCodeSyntax
            self.codeSyntaxTemplate = codeSyntaxTemplate
            self.sourceKind = sourceKind
            self.penpotSource = penpotSource
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

    /// iOS icons entry configuration.
    public struct IconsEntry: Common.FrameSource {
        public static let registeredIdentifier: String = "iOS#IconsEntry"

        /// Vector format for icons.
        public var format: Common.VectorFormat

        /// Path to .xcassets folder for icons.
        public var assetsFolder: String

        /// Asset names that preserve vector representation.
        public var preservesVectorRepresentation: [String]?

        /// Naming style for generated icon names.
        public var nameStyle: Common.NameStyle

        /// Path to generate UIImage extension Swift file.
        public var imageSwift: String?

        /// Path to generate SwiftUI Image extension Swift file.
        public var swiftUIImageSwift: String?

        /// Path to generate Figma Code Connect Swift file.
        public var codeConnectSwift: String?

        /// Override path to .xcassets folder for this entry.
        /// When set, overrides `iOSConfig.xcassetsPath`.
        public var xcassetsPath: String?

        /// Override path to custom Jinja2 templates for this entry.
        /// When set, overrides `iOSConfig.templatesPath`.
        public var templatesPath: String?

        /// Default render mode for assets.
        public var renderMode: XcodeRenderMode?

        /// Suffix for assets using default render mode.
        public var renderModeDefaultSuffix: String?

        /// Suffix for assets using original render mode.
        public var renderModeOriginalSuffix: String?

        /// Suffix for assets using template render mode.
        public var renderModeTemplateSuffix: String?

        /// Design source kind override. When null, auto-detected:
        /// - If `penpotSource` is set → "penpot"
        /// - Otherwise → "figma"
        public var sourceKind: Common.SourceKind?

        /// Penpot source configuration (bypasses Figma API when set).
        public var penpotSource: Common.PenpotSource?

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

        /// Values of the RTL variant property that indicate "active" RTL direction.
        /// Components with these values are skipped during export — the base variant
        /// is mirrored at runtime by the platform.
        /// Default: `new { "On" }`. Set to `new { "On"; "true" }` if your Figma file
        /// uses both naming conventions.
        public var rtlActiveValues: [String]?

        /// Dark mode generation via Figma Variable bindings.
        /// When set, dark SVG variants are generated by resolving variable bindings
        /// and replacing colors in the light SVG.
        public var variablesDarkMode: Common.VariablesDarkMode?

        /// Regex pattern for validating/capturing names.
        public var nameValidateRegexp: String?

        /// Replacement pattern using captured groups.
        public var nameReplaceRegexp: String?

        public init(
            format: Common.VectorFormat,
            assetsFolder: String,
            preservesVectorRepresentation: [String]?,
            nameStyle: Common.NameStyle,
            imageSwift: String?,
            swiftUIImageSwift: String?,
            codeConnectSwift: String?,
            xcassetsPath: String?,
            templatesPath: String?,
            renderMode: XcodeRenderMode?,
            renderModeDefaultSuffix: String?,
            renderModeOriginalSuffix: String?,
            renderModeTemplateSuffix: String?,
            sourceKind: Common.SourceKind?,
            penpotSource: Common.PenpotSource?,
            figmaFrameName: String?,
            figmaPageName: String?,
            figmaFileId: String?,
            rtlProperty: String?,
            rtlActiveValues: [String]?,
            variablesDarkMode: Common.VariablesDarkMode?,
            nameValidateRegexp: String?,
            nameReplaceRegexp: String?
        ) {
            self.format = format
            self.assetsFolder = assetsFolder
            self.preservesVectorRepresentation = preservesVectorRepresentation
            self.nameStyle = nameStyle
            self.imageSwift = imageSwift
            self.swiftUIImageSwift = swiftUIImageSwift
            self.codeConnectSwift = codeConnectSwift
            self.xcassetsPath = xcassetsPath
            self.templatesPath = templatesPath
            self.renderMode = renderMode
            self.renderModeDefaultSuffix = renderModeDefaultSuffix
            self.renderModeOriginalSuffix = renderModeOriginalSuffix
            self.renderModeTemplateSuffix = renderModeTemplateSuffix
            self.sourceKind = sourceKind
            self.penpotSource = penpotSource
            self.figmaFrameName = figmaFrameName
            self.figmaPageName = figmaPageName
            self.figmaFileId = figmaFileId
            self.rtlProperty = rtlProperty
            self.rtlActiveValues = rtlActiveValues
            self.variablesDarkMode = variablesDarkMode
            self.nameValidateRegexp = nameValidateRegexp
            self.nameReplaceRegexp = nameReplaceRegexp
        }
    }

    /// iOS images entry configuration.
    public struct ImagesEntry: Common.FrameSource {
        public static let registeredIdentifier: String = "iOS#ImagesEntry"

        /// Path to .xcassets folder for images.
        public var assetsFolder: String

        /// Naming style for generated image names.
        public var nameStyle: Common.NameStyle

        /// Scale factors to generate (e.g., [1, 2, 3]).
        public var scales: [Float64]?

        /// Path to generate UIImage extension Swift file.
        public var imageSwift: String?

        /// Path to generate SwiftUI Image extension Swift file.
        public var swiftUIImageSwift: String?

        /// Path to generate Figma Code Connect Swift file.
        public var codeConnectSwift: String?

        /// Source format for fetching from Figma API.
        public var sourceFormat: Common.SourceFormat?

        /// Output format for asset catalog.
        public var outputFormat: ImageOutputFormat?

        /// HEIC encoding options. Only used when outputFormat is heic.
        public var heicOptions: HeicOptions?

        /// Override path to .xcassets folder for this entry.
        /// When set, overrides `iOSConfig.xcassetsPath`.
        public var xcassetsPath: String?

        /// Override path to custom Jinja2 templates for this entry.
        /// When set, overrides `iOSConfig.templatesPath`.
        public var templatesPath: String?

        /// Default render mode for assets.
        public var renderMode: XcodeRenderMode?

        /// Suffix for assets using default render mode.
        public var renderModeDefaultSuffix: String?

        /// Suffix for assets using original render mode.
        public var renderModeOriginalSuffix: String?

        /// Suffix for assets using template render mode.
        public var renderModeTemplateSuffix: String?

        /// Design source kind override. When null, auto-detected:
        /// - If `penpotSource` is set → "penpot"
        /// - Otherwise → "figma"
        public var sourceKind: Common.SourceKind?

        /// Penpot source configuration (bypasses Figma API when set).
        public var penpotSource: Common.PenpotSource?

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

        /// Values of the RTL variant property that indicate "active" RTL direction.
        /// Components with these values are skipped during export — the base variant
        /// is mirrored at runtime by the platform.
        /// Default: `new { "On" }`. Set to `new { "On"; "true" }` if your Figma file
        /// uses both naming conventions.
        public var rtlActiveValues: [String]?

        /// Dark mode generation via Figma Variable bindings.
        /// When set, dark SVG variants are generated by resolving variable bindings
        /// and replacing colors in the light SVG.
        public var variablesDarkMode: Common.VariablesDarkMode?

        /// Regex pattern for validating/capturing names.
        public var nameValidateRegexp: String?

        /// Replacement pattern using captured groups.
        public var nameReplaceRegexp: String?

        public init(
            assetsFolder: String,
            nameStyle: Common.NameStyle,
            scales: [Float64]?,
            imageSwift: String?,
            swiftUIImageSwift: String?,
            codeConnectSwift: String?,
            sourceFormat: Common.SourceFormat?,
            outputFormat: ImageOutputFormat?,
            heicOptions: HeicOptions?,
            xcassetsPath: String?,
            templatesPath: String?,
            renderMode: XcodeRenderMode?,
            renderModeDefaultSuffix: String?,
            renderModeOriginalSuffix: String?,
            renderModeTemplateSuffix: String?,
            sourceKind: Common.SourceKind?,
            penpotSource: Common.PenpotSource?,
            figmaFrameName: String?,
            figmaPageName: String?,
            figmaFileId: String?,
            rtlProperty: String?,
            rtlActiveValues: [String]?,
            variablesDarkMode: Common.VariablesDarkMode?,
            nameValidateRegexp: String?,
            nameReplaceRegexp: String?
        ) {
            self.assetsFolder = assetsFolder
            self.nameStyle = nameStyle
            self.scales = scales
            self.imageSwift = imageSwift
            self.swiftUIImageSwift = swiftUIImageSwift
            self.codeConnectSwift = codeConnectSwift
            self.sourceFormat = sourceFormat
            self.outputFormat = outputFormat
            self.heicOptions = heicOptions
            self.xcassetsPath = xcassetsPath
            self.templatesPath = templatesPath
            self.renderMode = renderMode
            self.renderModeDefaultSuffix = renderModeDefaultSuffix
            self.renderModeOriginalSuffix = renderModeOriginalSuffix
            self.renderModeTemplateSuffix = renderModeTemplateSuffix
            self.sourceKind = sourceKind
            self.penpotSource = penpotSource
            self.figmaFrameName = figmaFrameName
            self.figmaPageName = figmaPageName
            self.figmaFileId = figmaFileId
            self.rtlProperty = rtlProperty
            self.rtlActiveValues = rtlActiveValues
            self.variablesDarkMode = variablesDarkMode
            self.nameValidateRegexp = nameValidateRegexp
            self.nameReplaceRegexp = nameReplaceRegexp
        }
    }

    /// iOS typography configuration.
    public struct Typography: PklRegisteredType, Decodable, Hashable, Sendable {
        public static let registeredIdentifier: String = "iOS#Typography"

        /// Figma file ID override for typography (optional).
        public var fileId: String?

        /// Regex pattern for validating/capturing text style names.
        public var nameValidateRegexp: String?

        /// Replacement pattern for text style names.
        public var nameReplaceRegexp: String?

        /// Path to generate UIFont extension Swift file.
        public var fontSwift: String?

        /// Path to generate UILabel.Style extension Swift file.
        public var labelStyleSwift: String?

        /// Path to generate SwiftUI Font extension Swift file.
        public var swiftUIFontSwift: String?

        /// Generate UILabel subclasses for each style.
        public var generateLabels: Bool

        /// Directory to generate label subclasses.
        public var labelsDirectory: String?

        /// Naming style for generated font names.
        public var nameStyle: Common.NameStyle

        public init(
            fileId: String?,
            nameValidateRegexp: String?,
            nameReplaceRegexp: String?,
            fontSwift: String?,
            labelStyleSwift: String?,
            swiftUIFontSwift: String?,
            generateLabels: Bool,
            labelsDirectory: String?,
            nameStyle: Common.NameStyle
        ) {
            self.fileId = fileId
            self.nameValidateRegexp = nameValidateRegexp
            self.nameReplaceRegexp = nameReplaceRegexp
            self.fontSwift = fontSwift
            self.labelStyleSwift = labelStyleSwift
            self.swiftUIFontSwift = swiftUIFontSwift
            self.generateLabels = generateLabels
            self.labelsDirectory = labelsDirectory
            self.nameStyle = nameStyle
        }
    }

    /// Root iOS platform configuration.
    public struct iOSConfig: PklRegisteredType, Decodable, Hashable, Sendable {
        public static let registeredIdentifier: String = "iOS#iOSConfig"

        /// Path to .xcodeproj file.
        public var xcodeprojPath: String

        /// Xcode target name.
        public var target: String

        /// Path to main .xcassets folder.
        /// Required for colors (with useColorAssets), icons, and images export.
        /// Can be omitted in base configs that don't directly export assets.
        public var xcassetsPath: String?

        /// Whether assets are in main bundle.
        public var xcassetsInMainBundle: Bool

        /// Whether assets are in Swift Package.
        public var xcassetsInSwiftPackage: Bool?

        /// Resource bundle names for asset lookup.
        public var resourceBundleNames: [String]?

        /// Add @objc attribute to generated extensions.
        public var addObjcAttribute: Bool?

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
            xcodeprojPath: String,
            target: String,
            xcassetsPath: String?,
            xcassetsInMainBundle: Bool,
            xcassetsInSwiftPackage: Bool?,
            resourceBundleNames: [String]?,
            addObjcAttribute: Bool?,
            templatesPath: String?,
            colors: [ColorsEntry]?,
            icons: [IconsEntry]?,
            images: [ImagesEntry]?,
            typography: Typography?
        ) {
            self.xcodeprojPath = xcodeprojPath
            self.target = target
            self.xcassetsPath = xcassetsPath
            self.xcassetsInMainBundle = xcassetsInMainBundle
            self.xcassetsInSwiftPackage = xcassetsInSwiftPackage
            self.resourceBundleNames = resourceBundleNames
            self.addObjcAttribute = addObjcAttribute
            self.templatesPath = templatesPath
            self.colors = colors
            self.icons = icons
            self.images = images
            self.typography = typography
        }
    }

    /// Load the Pkl module at the given source and evaluate it into `iOS.Module`.
    ///
    /// - Parameter source: The source of the Pkl module.
    public static func loadFrom(source: ModuleSource) async throws -> iOS.Module {
        try await PklSwift.withEvaluator { evaluator in
            try await loadFrom(evaluator: evaluator, source: source)
        }
    }

    /// Load the Pkl module at the given source and evaluate it with the given evaluator into
    /// `iOS.Module`.
    ///
    /// - Parameter evaluator: The evaluator to use for evaluation.
    /// - Parameter source: The module to evaluate.
    public static func loadFrom(
        evaluator: PklSwift.Evaluator,
        source: PklSwift.ModuleSource
    ) async throws -> iOS.Module {
        try await evaluator.evaluateModule(source: source, as: Module.self)
    }
}
