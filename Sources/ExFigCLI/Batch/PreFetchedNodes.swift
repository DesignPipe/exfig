import FigmaAPI

/// Pre-fetched node documents for granular cache optimization.
///
/// When batch processing multiple configs that reference the same Figma files,
/// this storage allows sharing pre-fetched node documents across all configs,
/// avoiding redundant API calls to the Nodes endpoint.
struct PreFetchedNodes {
    /// Stored nodes keyed by fileId, then by nodeId.
    private let nodes: [String: [NodeId: Node]]

    /// Creates a new storage with pre-fetched nodes.
    /// - Parameter nodes: Dictionary mapping fileId to its node documents.
    init(nodes: [String: [NodeId: Node]]) {
        self.nodes = nodes
    }

    /// Get pre-fetched node for a specific fileId and nodeId.
    /// - Parameters:
    ///   - fileId: The Figma file ID.
    ///   - nodeId: The node ID to look up.
    /// - Returns: The node if pre-fetched, nil otherwise.
    func node(fileId: String, nodeId: NodeId) -> Node? {
        nodes[fileId]?[nodeId]
    }

    /// Get all pre-fetched nodes for a fileId.
    /// - Parameter fileId: The Figma file ID to look up.
    /// - Returns: All nodes for this file if pre-fetched, nil otherwise.
    func nodes(for fileId: String) -> [NodeId: Node]? {
        nodes[fileId]
    }

    /// Number of files with pre-fetched nodes.
    var fileCount: Int {
        nodes.count
    }

    /// Total number of pre-fetched nodes across all files.
    var totalNodeCount: Int {
        nodes.values.reduce(0) { $0 + $1.count }
    }
}
