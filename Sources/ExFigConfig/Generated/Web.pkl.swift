// Code generated from Pkl module `Web`. DO NOT EDIT.
import PklSwift

public enum Web {}

extension Web {
    /// Web platform configuration for ExFig.
    public struct Module: PklRegisteredType, Decodable, Hashable, Sendable {
        public static let registeredIdentifier: String = "Web"

        public init() {}
    }

    /// Web colors entry configuration.
    public struct ColorsEntry: Common.VariablesSource {
        public static let registeredIdentifier: String = "Web#ColorsEntry"

        /// Override base output directory for this entry.
        /// When set, overrides `WebConfig.output`.
        public var output: String?

        /// Override path to custom Jinja2 templates for this entry.
        /// When set, overrides `WebConfig.templatesPath`.
        public var templatesPath: String?

        /// Output directory for generated color files.
        public var outputDirectory: String?

        /// CSS filename for CSS variables. Default: colors.css
        public var cssFileName: String?

        /// TypeScript filename for type definitions. Default: colors.ts
        public var tsFileName: String?

        /// JSON filename for color data. Default: colors.json
        public var jsonFileName: String?

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
            output: String?,
            templatesPath: String?,
            outputDirectory: String?,
            cssFileName: String?,
            tsFileName: String?,
            jsonFileName: String?,
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
            self.output = output
            self.templatesPath = templatesPath
            self.outputDirectory = outputDirectory
            self.cssFileName = cssFileName
            self.tsFileName = tsFileName
            self.jsonFileName = jsonFileName
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

    /// Web icons entry configuration.
    public struct IconsEntry: Common.FrameSource {
        public static let registeredIdentifier: String = "Web#IconsEntry"

        /// Override path to custom Jinja2 templates for this entry.
        /// When set, overrides `WebConfig.templatesPath`.
        public var templatesPath: String?

        /// Output directory for generated icon components.
        public var outputDirectory: String

        /// Directory for raw SVG files.
        public var svgDirectory: String?

        /// Generate React components for icons.
        public var generateReactComponents: Bool?

        /// Icon size in pixels for viewBox.
        public var iconSize: Int?

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
            outputDirectory: String,
            svgDirectory: String?,
            generateReactComponents: Bool?,
            iconSize: Int?,
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
            self.outputDirectory = outputDirectory
            self.svgDirectory = svgDirectory
            self.generateReactComponents = generateReactComponents
            self.iconSize = iconSize
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

    /// Web images entry configuration.
    public struct ImagesEntry: Common.FrameSource {
        public static let registeredIdentifier: String = "Web#ImagesEntry"

        /// Override path to custom Jinja2 templates for this entry.
        /// When set, overrides `WebConfig.templatesPath`.
        public var templatesPath: String?

        /// Output directory for generated image components.
        public var outputDirectory: String

        /// Directory for image asset files.
        public var assetsDirectory: String?

        /// Generate React components for images.
        public var generateReactComponents: Bool?

        /// Naming style for generated image names.
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
            outputDirectory: String,
            assetsDirectory: String?,
            generateReactComponents: Bool?,
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
            self.outputDirectory = outputDirectory
            self.assetsDirectory = assetsDirectory
            self.generateReactComponents = generateReactComponents
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

    /// Root Web platform configuration.
    public struct WebConfig: PklRegisteredType, Decodable, Hashable, Sendable {
        public static let registeredIdentifier: String = "Web#WebConfig"

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

    /// Load the Pkl module at the given source and evaluate it into `Web.Module`.
    ///
    /// - Parameter source: The source of the Pkl module.
    public static func loadFrom(source: ModuleSource) async throws -> Web.Module {
        try await PklSwift.withEvaluator { evaluator in
            try await loadFrom(evaluator: evaluator, source: source)
        }
    }

    /// Load the Pkl module at the given source and evaluate it with the given evaluator into
    /// `Web.Module`.
    ///
    /// - Parameter evaluator: The evaluator to use for evaluation.
    /// - Parameter source: The module to evaluate.
    public static func loadFrom(
        evaluator: PklSwift.Evaluator,
        source: PklSwift.ModuleSource
    ) async throws -> Web.Module {
        try await evaluator.evaluateModule(source: source, as: Module.self)
    }
}
