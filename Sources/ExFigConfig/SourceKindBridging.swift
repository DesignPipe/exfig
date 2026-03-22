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

public extension Common_FrameSource {
    /// Resolves the design source kind with priority: explicit > auto-detect > default (.figma).
    ///
    /// Auto-detection: `penpotSource` set → `.penpot`, otherwise `.figma`.
    var resolvedSourceKind: DesignSourceKind {
        if let explicit = sourceKind {
            return explicit.coreSourceKind
        }
        if penpotSource != nil {
            return .penpot
        }
        return .figma
    }

    /// Resolves the file ID based on the resolved source kind.
    ///
    /// When source is Penpot, returns only the Penpot file ID (not Figma's)
    /// to prevent passing a Figma file key to the Penpot API.
    var resolvedFileId: String? {
        if resolvedSourceKind == .penpot {
            return penpotSource?.fileId
        }
        return figmaFileId
    }

    /// Resolves the Penpot base URL from penpotSource config.
    var resolvedPenpotBaseURL: String? {
        penpotSource?.baseUrl
    }
}
