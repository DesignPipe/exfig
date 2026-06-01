// Code generated from Pkl module `Lint`. DO NOT EDIT.
import PklSwift

public enum Lint {}

public protocol Lint_Module: PklRegisteredType, DynamicallyEquatable, Hashable, Sendable {
    var iconColorVariables: [Lint.IconColorVariablesRule]? { get }
}

extension Lint {
    public typealias Module = Lint_Module

    /// Lint-only configuration schema.
    ///
    /// This module is intentionally separate from ExFig export configuration.
    /// It describes additional design policies for `exfig lint` without changing
    /// what ExFig exports.
    public struct ModuleImpl: Module {
        public static let registeredIdentifier: String = "Lint"

        /// Icon color variable lint policies.
        public var iconColorVariables: [IconColorVariablesRule]?

        public init(iconColorVariables: [IconColorVariablesRule]?) {
            self.iconColorVariables = iconColorVariables
        }
    }

    /// Expected Figma Variables for icon paints.
    public struct IconColorVariablesRule: PklRegisteredType, Decodable, Hashable, Sendable {
        public static let registeredIdentifier: String = "Lint#IconColorVariablesRule"

        /// Selects existing icon entries from the main ExFig config.
        public var selector: IconSelector

        /// Optional variable file override. Normally inferred from the main config.
        public var variablesFileId: String?

        /// Whether matching paints must be bound to a Figma Variable.
        public var requireBound: Bool

        /// Allowed variable names for both fills and strokes.
        public var paints: [String]?

        /// Allowed variable names for fills.
        public var fills: [String]?

        /// Allowed variable names for strokes.
        public var strokes: [String]?

        public init(
            selector: IconSelector,
            variablesFileId: String?,
            requireBound: Bool,
            paints: [String]?,
            fills: [String]?,
            strokes: [String]?
        ) {
            self.selector = selector
            self.variablesFileId = variablesFileId
            self.requireBound = requireBound
            self.paints = paints
            self.fills = fills
            self.strokes = strokes
        }
    }

    /// Selects icon entries from the main ExFig config.
    public struct IconSelector: PklRegisteredType, Decodable, Hashable, Sendable {
        public static let registeredIdentifier: String = "Lint#IconSelector"

        /// Figma file ID to match.
        public var figmaFileId: String?

        /// Figma page name to match.
        public var figmaPageName: String?

        /// Figma frame name to match.
        public var figmaFrameName: String?

        /// Export assets folder to match.
        public var assetsFolder: String?

        public init(
            figmaFileId: String?,
            figmaPageName: String?,
            figmaFrameName: String?,
            assetsFolder: String?
        ) {
            self.figmaFileId = figmaFileId
            self.figmaPageName = figmaPageName
            self.figmaFrameName = figmaFrameName
            self.assetsFolder = assetsFolder
        }
    }
}