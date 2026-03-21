import ExFigCore

public extension Common.SourceKind {
    /// Converts PKL `Common.SourceKind` to `ExFigCore.DesignSourceKind`.
    ///
    /// PKL uses kebab-case raw values ("tokens-file") while ExFigCore uses camelCase ("tokensFile").
    /// Cases with single-word names match directly; multi-word cases need explicit mapping.
    var coreSourceKind: DesignSourceKind {
        switch self {
        case .figma: .figma
        case .penpot: .penpot
        case .tokensFile: .tokensFile
        case .tokensStudio: .tokensStudio
        case .sketchFile: .sketchFile
        }
    }
}
