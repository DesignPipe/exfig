import Foundation

/// Reconstructs SVG from Penpot shape tree data.
///
/// Penpot shapes are SVG-compatible objects stored in a flat dictionary keyed by ID.
/// Each shape has canvas-space coordinates that must be normalized relative to the
/// root frame's origin.
public enum PenpotShapeRenderer {
    /// Renders a component's shape tree as an SVG string.
    ///
    /// - Parameters:
    ///   - objects: Flat dictionary of all shapes on the page (from `PenpotPage.objects`)
    ///   - rootId: The component's `mainInstanceId` — the root frame shape
    /// - Returns: SVG string with coordinates normalized to (0,0), or nil if root not found
    /// Describes why SVG rendering failed.
    public enum RenderFailure: Error, Sendable {
        case rootNotFound(id: String)
        case missingSelrect(id: String)
    }

    /// Result of SVG rendering including any warnings about skipped shapes.
    public struct RenderResult: Sendable {
        public let svg: String
        public let skippedShapeTypes: Set<String>
    }

    /// Renders a component's shape tree as an SVG string with diagnostics.
    public static func renderSVGResult(
        objects: [String: PenpotShape],
        rootId: String
    ) -> Result<RenderResult, RenderFailure> {
        guard let root = objects[rootId] else {
            return .failure(.rootNotFound(id: rootId))
        }
        guard let selrect = root.selrect else {
            return .failure(.missingSelrect(id: rootId))
        }

        let originX = selrect.x
        let originY = selrect.y
        let width = selrect.width
        let height = selrect.height

        var skippedTypes: Set<String> = []

        var svg = """
        <svg xmlns="http://www.w3.org/2000/svg" \
        width="\(formatNumber(width))" height="\(formatNumber(height))" \
        viewBox="0 0 \(formatNumber(width)) \(formatNumber(height))">
        """

        for childId in root.shapes ?? [] {
            svg += renderShape(
                id: childId,
                objects: objects,
                originX: originX,
                originY: originY,
                skippedTypes: &skippedTypes
            )
        }

        svg += "\n</svg>"
        return .success(RenderResult(svg: svg, skippedShapeTypes: skippedTypes))
    }

    /// Convenience wrapper that returns just the SVG string, or nil on failure.
    public static func renderSVG(
        objects: [String: PenpotShape],
        rootId: String
    ) -> String? {
        switch renderSVGResult(objects: objects, rootId: rootId) {
        case let .success(result): result.svg
        case .failure: nil
        }
    }

    // MARK: - Private

    private static func renderShape(
        id: String,
        objects: [String: PenpotShape],
        originX: Double,
        originY: Double,
        skippedTypes: inout Set<String>
    ) -> String {
        guard let shape = objects[id] else { return "" }
        if shape.hidden == true { return "" }

        let rotation = shape.rotation ?? 0
        let needsTransform = rotation != 0

        var result = ""

        // Wrap in <g transform="rotate(...)"> if rotated
        if needsTransform, let cx = shape.x, let cy = shape.y,
           let w = shape.width, let h = shape.height
        {
            let rcx = formatNumber(cx - originX + w / 2)
            let rcy = formatNumber(cy - originY + h / 2)
            result += "\n<g transform=\"rotate(\(formatNumber(rotation)) \(rcx) \(rcy))\">"
        }

        switch shape.type {
        case .path, .bool:
            result += renderPath(shape, originX: originX, originY: originY)
        case .rect:
            result += renderRect(shape, originX: originX, originY: originY)
        case .circle:
            result += renderEllipse(shape, originX: originX, originY: originY)
        case .group, .frame:
            result += renderGroup(
                shape, objects: objects, originX: originX, originY: originY,
                skippedTypes: &skippedTypes
            )
        case let .unknown(typeName):
            skippedTypes.insert(typeName)
        }

        if needsTransform {
            result += "\n</g>"
        }

        return result
    }

    private static func renderPath(
        _ shape: PenpotShape,
        originX: Double,
        originY: Double
    ) -> String {
        guard let pathData = shape.content?.pathData, !pathData.isEmpty else { return "" }

        let normalized = normalizePathCoordinates(pathData, originX: originX, originY: originY)
        let attrs = styleAttributes(fills: shape.fills, strokes: shape.strokes, svgAttrs: shape.svgAttrs)

        return "\n<path d=\"\(normalized)\"\(attrs)/>"
    }

    private static func renderRect(
        _ shape: PenpotShape,
        originX: Double,
        originY: Double
    ) -> String {
        guard let x = shape.x, let y = shape.y,
              let w = shape.width, let h = shape.height else { return "" }

        let nx = formatNumber(x - originX)
        let ny = formatNumber(y - originY)
        let attrs = styleAttributes(fills: shape.fills, strokes: shape.strokes, svgAttrs: shape.svgAttrs)

        // Border radius — use r1 if all corners are equal, otherwise rx
        let rx = shape.r1 ?? 0
        let rxAttr = rx > 0 ? " rx=\"\(formatNumber(rx))\"" : ""

        let size = "width=\"\(formatNumber(w))\" height=\"\(formatNumber(h))\""
        return "\n<rect x=\"\(nx)\" y=\"\(ny)\" \(size)\(rxAttr)\(attrs)/>"
    }

    private static func renderEllipse(
        _ shape: PenpotShape,
        originX: Double,
        originY: Double
    ) -> String {
        guard let x = shape.x, let y = shape.y,
              let w = shape.width, let h = shape.height else { return "" }

        let cx = formatNumber(x - originX + w / 2)
        let cy = formatNumber(y - originY + h / 2)
        let rx = formatNumber(w / 2)
        let ry = formatNumber(h / 2)
        let attrs = styleAttributes(fills: shape.fills, strokes: shape.strokes, svgAttrs: shape.svgAttrs)

        return "\n<ellipse cx=\"\(cx)\" cy=\"\(cy)\" rx=\"\(rx)\" ry=\"\(ry)\"\(attrs)/>"
    }

    private static func renderGroup(
        _ shape: PenpotShape,
        objects: [String: PenpotShape],
        originX: Double,
        originY: Double,
        skippedTypes: inout Set<String>
    ) -> String {
        guard let children = shape.shapes, !children.isEmpty else { return "" }

        let attrs = styleAttributes(fills: shape.fills, strokes: shape.strokes, svgAttrs: shape.svgAttrs)
        var result = "\n<g\(attrs)>"

        for childId in children {
            result += renderShape(
                id: childId, objects: objects, originX: originX, originY: originY,
                skippedTypes: &skippedTypes
            )
        }

        result += "\n</g>"
        return result
    }

    // MARK: - Style Attributes

    private static func styleAttributes(
        fills: [PenpotShape.Fill]?,
        strokes: [PenpotShape.Stroke]?,
        svgAttrs: PenpotShape.SVGAttributes?
    ) -> String {
        var attrs: [String] = []

        // Fill from svgAttrs takes priority (e.g., fill="none" for stroke-only icons)
        if let svgFill = svgAttrs?["fill"] {
            attrs.append("fill=\"\(svgFill)\"")
        } else if let fill = fills?.first, let color = fill.fillColor {
            let opacity = fill.fillOpacity ?? 1.0
            attrs.append("fill=\"\(color)\"")
            if opacity < 1.0 {
                attrs.append("fill-opacity=\"\(formatNumber(opacity))\"")
            }
        } else if fills?.isEmpty == true {
            attrs.append("fill=\"none\"")
        }

        // Stroke
        if let stroke = strokes?.first, let color = stroke.strokeColor {
            attrs.append("stroke=\"\(color)\"")
            if let width = stroke.strokeWidth {
                attrs.append("stroke-width=\"\(formatNumber(width))\"")
            }
            if let opacity = stroke.strokeOpacity, opacity < 1.0 {
                attrs.append("stroke-opacity=\"\(formatNumber(opacity))\"")
            }
            if let cap = stroke.strokeCapStart, cap != "butt" {
                let svgCap = mapStrokeCap(cap)
                attrs.append("stroke-linecap=\"\(svgCap)\"")
            }
        }

        if attrs.isEmpty { return "" }
        return " " + attrs.joined(separator: " ")
    }

    private static func mapStrokeCap(_ penpotCap: String) -> String {
        switch penpotCap {
        case "round", "circle-marker": "round"
        case "square": "square"
        default: "butt"
        }
    }

    // MARK: - Coordinate Normalization

    /// Normalizes SVG path data by subtracting the origin offset from all coordinate values.
    static func normalizePathCoordinates(
        _ pathData: String,
        originX: Double,
        originY: Double
    ) -> String {
        var result = ""
        var i = pathData.startIndex
        var state = PathNormState()

        while i < pathData.endIndex {
            let ch = pathData[i]

            if ch.isLetter {
                result.append(ch)
                state.setCommand(ch)
                i = pathData.index(after: i)
            } else if ch == "," || ch == " " {
                result.append(ch)
                i = pathData.index(after: i)
            } else if ch == "-" || ch == "." || ch.isNumber {
                let (numStr, nextIndex) = parseNumber(in: pathData, from: i)
                if let value = Double(numStr) {
                    let cmd = state.currentCmd ?? findLastCommand(in: pathData, before: i)
                    result.append(offsetValue(value, cmd: cmd, state: &state, originX: originX, originY: originY))
                } else {
                    result.append(numStr)
                }
                i = nextIndex
            } else {
                result.append(ch)
                i = pathData.index(after: i)
            }
        }

        return result
    }

    /// Mutable state for path coordinate normalization.
    private struct PathNormState {
        var isX = true
        var currentCmd: Character?
        var arcParamIndex = 0

        mutating func setCommand(_ ch: Character) {
            currentCmd = ch
            isX = true
            arcParamIndex = 0
        }
    }

    private static func parseNumber(in path: String, from start: String.Index) -> (String, String.Index) {
        var numStr = ""
        var j = start
        if path[j] == "-" {
            numStr.append("-")
            j = path.index(after: j)
        }
        var hasDot = false
        while j < path.endIndex {
            let c = path[j]
            if c.isNumber {
                numStr.append(c)
            } else if c == ".", !hasDot {
                hasDot = true
                numStr.append(c)
            } else {
                break
            }
            j = path.index(after: j)
        }
        return (numStr, j)
    }

    private static func offsetValue(
        _ value: Double, cmd: Character?, state: inout PathNormState,
        originX: Double, originY: Double
    ) -> String {
        guard let cmd, cmd.isUppercase, cmd != "Z" else {
            return formatNumber(value)
        }

        if cmd == "A" {
            // Arc: 7 params per segment (rx, ry, x-rotation, large-arc, sweep, x, y)
            // Only params 5 (x) and 6 (y) are endpoint coordinates
            let paramPos = state.arcParamIndex % 7
            state.arcParamIndex += 1
            if paramPos == 5 { return formatNumber(value - originX) }
            if paramPos == 6 { return formatNumber(value - originY) }
            return formatNumber(value)
        }

        let offset = state.isX ? originX : originY
        state.isX.toggle()
        return formatNumber(value - offset)
    }

    private static func findLastCommand(in path: String, before index: String.Index) -> Character? {
        var j = index
        while j > path.startIndex {
            j = path.index(before: j)
            if path[j].isLetter { return path[j] }
        }
        return nil
    }

    // MARK: - Formatting

    private static func formatNumber(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1_000_000 {
            return String(Int(value))
        }
        // Round to 2 decimal places to keep SVG compact
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(rounded)
    }
}
