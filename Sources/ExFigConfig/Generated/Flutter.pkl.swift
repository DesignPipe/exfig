// Code generated from Pkl module `Flutter`. DO NOT EDIT.
import PklSwift

public enum Flutter {}

extension Flutter {
    /// Flutter image format.
    public enum ImageFormat: String, CaseIterable, CodingKeyRepresentable, Decodable, Hashable, Sendable {
        case svg = "svg"
        case png = "png"
        case webp = "webp"
    }

    /// Flutter platform configuration for ExFig.
    public struct Module: PklRegisteredType, Decodable, Hashable, Sendable {
        public static let registeredIdentifier: String = "Flutter"

        public init() {}
    }

    /// Flutter colors entry configuration.
    public struct ColorsEntry: Common.VariablesSource {
        public static let registeredIdentifier: String = "Flutter#ColorsEntry"

        /// Override path to custom Jinja2 templates for this entry.
        /// When set, overrides `FlutterConfig.templatesPath`.
        public var templatesPath: String?

        /// Output path for generated Dart colors file.
        public var output: String?

        /// Class name for generated colors.
        public var className: String?

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
            templatesPath: String?,
            output: String?,
            className: String?,
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
            self.templatesPath = templatesPath
            self.output = output
            self.className = className
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

    /// Flutter icons entry configuration.
    public struct IconsEntry: Common.FrameSource {
        public static let registeredIdentifier: String = "Flutter#IconsEntry"

        /// Override path to custom Jinja2 templates for this entry.
        /// When set, overrides `FlutterConfig.templatesPath`.
        public var templatesPath: String?

        /// Output directory for icon SVG files.
        public var output: String

        /// Dart file path for icon class generation.
        public var dartFile: String?

        /// Class name for generated icons.
        public var className: String?

        /// Naming style for icon names.
        public var nameStyle: Common.NameStyle?

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
            templatesPath: String?,
            output: String,
            dartFile: String?,
            className: String?,
            nameStyle: Common.NameStyle?,
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
            self.templatesPath = templatesPath
            self.output = output
            self.dartFile = dartFile
            self.className = className
            self.nameStyle = nameStyle
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

    /// Flutter images entry configuration.
    public struct ImagesEntry: Common.FrameSource {
        public static let registeredIdentifier: String = "Flutter#ImagesEntry"

        /// Override path to custom Jinja2 templates for this entry.
        /// When set, overrides `FlutterConfig.templatesPath`.
        public var templatesPath: String?

        /// Output directory for image files.
        public var output: String

        /// Dart file path for image class generation.
        public var dartFile: String?

        /// Class name for generated images.
        public var className: String?

        /// Scale factors to generate (e.g., [1, 2, 3]).
        public var scales: [Float64]?

        /// Output format for images.
        public var format: ImageFormat?

        /// WebP encoding options.
        public var webpOptions: Common.WebpOptions?

        /// Source format for fetching from Figma API.
        public var sourceFormat: Common.SourceFormat?

        /// Naming style for generated assets.
        public var nameStyle: Common.NameStyle?

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
            templatesPath: String?,
            output: String,
            dartFile: String?,
            className: String?,
            scales: [Float64]?,
            format: ImageFormat?,
            webpOptions: Common.WebpOptions?,
            sourceFormat: Common.SourceFormat?,
            nameStyle: Common.NameStyle?,
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
            self.templatesPath = templatesPath
            self.output = output
            self.dartFile = dartFile
            self.className = className
            self.scales = scales
            self.format = format
            self.webpOptions = webpOptions
            self.sourceFormat = sourceFormat
            self.nameStyle = nameStyle
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

    /// Root Flutter platform configuration.
    public struct FlutterConfig: PklRegisteredType, Decodable, Hashable, Sendable {
        public static let registeredIdentifier: String = "Flutter#FlutterConfig"

        /// Base output directory for all generated files.
        public var output: String

        /// Path to custom Jinja2 templates.
        public var templatesPath: String?

        /// Colors configuration entries.
        public var colors: [ColorsEntry]?

        /// Icons configuration entries.
        public var icons: [IconsEntry]?

        /// Images configuration entries.
        public var images: [ImagesEntry]?

        public init(
            output: String,
            templatesPath: String?,
            colors: [ColorsEntry]?,
            icons: [IconsEntry]?,
            images: [ImagesEntry]?
        ) {
            self.output = output
            self.templatesPath = templatesPath
            self.colors = colors
            self.icons = icons
            self.images = images
        }
    }

    /// Load the Pkl module at the given source and evaluate it into `Flutter.Module`.
    ///
    /// - Parameter source: The source of the Pkl module.
    public static func loadFrom(source: ModuleSource) async throws -> Flutter.Module {
        try await PklSwift.withEvaluator { evaluator in
            try await loadFrom(evaluator: evaluator, source: source)
        }
    }

    /// Load the Pkl module at the given source and evaluate it with the given evaluator into
    /// `Flutter.Module`.
    ///
    /// - Parameter evaluator: The evaluator to use for evaluation.
    /// - Parameter source: The module to evaluate.
    public static func loadFrom(
        evaluator: PklSwift.Evaluator,
        source: PklSwift.ModuleSource
    ) async throws -> Flutter.Module {
        try await evaluator.evaluateModule(source: source, as: Module.self)
    }
}
