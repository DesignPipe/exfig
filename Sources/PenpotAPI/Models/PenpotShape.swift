import Foundation

/// A shape object from a Penpot page's object tree.
///
/// Shapes represent SVG-compatible design elements (rect, circle, path, group, frame).
/// Coordinates are in canvas-space — subtract the root frame's origin to normalize.
public struct PenpotShape: Decodable, Sendable {
    public let id: String
    public let name: String?
    public let type: ShapeType

    // Geometry
    public let x: Double?
    public let y: Double?
    public let width: Double?
    public let height: Double?
    public let rotation: Double?
    public let selrect: Selrect?

    /// SVG path data (for path/bool types)
    public let content: ShapeContent?

    // Styling
    public let fills: [Fill]?
    public let strokes: [Stroke]?
    public let svgAttrs: SVGAttributes?
    public let hideFillOnExport: Bool?

    /// Tree structure
    public let shapes: [String]?

    /// Boolean operations
    public let boolType: String?

    // Border radius (for rect type)
    public let r1: Double?
    public let r2: Double?
    public let r3: Double?
    public let r4: Double?

    /// Transform matrix
    public let transform: Transform?

    public let opacity: Double?
    public let hidden: Bool?
}

// MARK: - Shape Type

public extension PenpotShape {
    /// Known shape types from Penpot's shape tree.
    enum ShapeType: Sendable, Equatable, CustomStringConvertible {
        case path
        case rect
        case circle
        case group
        case frame
        case bool
        case unknown(String)

        public var description: String {
            switch self {
            case .path: "path"
            case .rect: "rect"
            case .circle: "circle"
            case .group: "group"
            case .frame: "frame"
            case .bool: "bool"
            case let .unknown(value): value
            }
        }
    }
}

extension PenpotShape.ShapeType: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "path": self = .path
        case "rect": self = .rect
        case "circle": self = .circle
        case "group": self = .group
        case "frame": self = .frame
        case "bool": self = .bool
        default: self = .unknown(rawValue)
        }
    }
}

// MARK: - Supporting Types

public extension PenpotShape {
    /// Content can be a String (SVG path data) or a structured object (text content).
    /// We only care about String paths for SVG reconstruction.
    enum ShapeContent: Decodable, Sendable {
        case path(String)
        case other

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self = .path(string)
            } else {
                self = .other
            }
        }

        public var pathData: String? {
            if case let .path(data) = self { return data }
            return nil
        }
    }

    struct Selrect: Decodable, Sendable {
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double
    }

    struct Fill: Decodable, Sendable {
        public let fillColor: String?
        public let fillOpacity: Double?
    }

    struct Stroke: Decodable, Sendable {
        public let strokeColor: String?
        public let strokeOpacity: Double?
        public let strokeWidth: Double?
        public let strokeStyle: String?
        public let strokeAlignment: String?
        public let strokeCapStart: String?
        public let strokeCapEnd: String?
    }

    struct Transform: Decodable, Sendable {
        public let a: Double
        public let b: Double
        public let c: Double
        public let d: Double
        public let e: Double
        public let f: Double

        /// Whether this is an identity transform.
        public var isIdentity: Bool {
            a == 1 && b == 0 && c == 0 && d == 1 && e == 0 && f == 0
        }
    }

    /// SVG attributes — values can be strings or nested dictionaries.
    /// We extract only string values for SVG reconstruction.
    struct SVGAttributes: Decodable, Sendable {
        public let values: [String: String]

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode([String: AnyCodable].self)
            var result: [String: String] = [:]
            for (key, value) in raw {
                if case let .string(s) = value {
                    result[key] = s
                }
            }
            values = result
        }

        public subscript(key: String) -> String? {
            values[key]
        }

        /// Flexible JSON value that handles strings, numbers, bools, and nested structures.
        private enum AnyCodable: Decodable, Sendable {
            case string(String)
            case other

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let s = try? container.decode(String.self) {
                    self = .string(s)
                } else {
                    self = .other
                }
            }
        }
    }
}

/// A page from a Penpot file containing a flat object tree.
public struct PenpotPage: Decodable, Sendable {
    public let name: String?
    public let objects: [String: PenpotShape]?
}
