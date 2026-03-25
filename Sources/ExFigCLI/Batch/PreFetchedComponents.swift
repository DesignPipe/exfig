import FigmaAPI

/// Pre-fetched components for batch processing optimization.
///
/// When batch processing multiple configs that reference the same Figma files,
/// this storage allows sharing pre-fetched components across all configs,
/// avoiding redundant API calls. Each config then filters components locally
/// by its `figmaFrameName`.
struct PreFetchedComponents {
    /// Stored components keyed by fileId.
    private let components: [String: [Component]]

    /// Creates a new storage with pre-fetched components.
    /// - Parameter components: Dictionary mapping fileId to its components.
    init(components: [String: [Component]]) {
        self.components = components
    }

    /// Get pre-fetched components for a fileId.
    /// - Parameter fileId: The Figma file ID to look up.
    /// - Returns: The components if pre-fetched, nil otherwise.
    func components(for fileId: String) -> [Component]? {
        components[fileId]
    }

    /// Check if a fileId has pre-fetched components.
    /// - Parameter fileId: The Figma file ID to check.
    /// - Returns: True if components exist for this fileId.
    func hasComponents(for fileId: String) -> Bool {
        components[fileId] != nil
    }

    /// Number of pre-fetched files.
    var count: Int {
        components.count
    }

    /// Total component count across all files.
    var totalComponentCount: Int {
        components.values.reduce(0) { $0 + $1.count }
    }

    /// Returns all file IDs that have pre-fetched components.
    func allFileIds() -> [String] {
        Array(components.keys)
    }
}
