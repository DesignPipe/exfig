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
        /// The default empty selector matches all icon entries.
        public var selector: IconSelector

        /// Optional variable file override. Normally inferred from the main config.
        public var variablesFileId: String?

        /// Whether matching paints must be bound to a Figma Variable.
        /// Only enforced for a role (fill/stroke) that has at least one allowed variable name configured.
        public var requireBound: Bool

        /// Allowed variable names applied to both fills and strokes.
        /// Merged with the role-specific `fills`/`strokes` lists (not mutually exclusive with them).
        public var paints: [String]?

        /// Allowed variable names for fills (in addition to `paints`).
        public var fills: [String]?

        /// Allowed variable names for strokes (in addition to `paints`).
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
    ///
    /// All fields are optional and combined with AND. An empty selector (the default,
    /// `new IconSelector {}`) matches every icon entry.
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
