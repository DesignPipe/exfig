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
    public static func renderSVG(
        objects: [String: PenpotShape],
        rootId: String
    ) -> String? {
        guard let root = objects[rootId] else { return nil }
        guard let selrect = root.selrect else { return nil }

        let originX = selrect.x
        let originY = selrect.y
        let width = selrect.width
        let height = selrect.height

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
                originY: originY
            )
        }

        svg += "\n</svg>"
        return svg
    }

    // MARK: - Private

    private static func renderShape(
        id: String,
        objects: [String: PenpotShape],
        originX: Double,
        originY: Double
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
        case "path", "bool":
            result += renderPath(shape, originX: originX, originY: originY)
        case "rect":
            result += renderRect(shape, originX: originX, originY: originY)
        case "circle":
            result += renderEllipse(shape, originX: originX, originY: originY)
        case "group", "frame":
            result += renderGroup(shape, objects: objects, originX: originX, originY: originY)
        default:
            break
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
        originY: Double
    ) -> String {
        guard let children = shape.shapes, !children.isEmpty else { return "" }

        let attrs = styleAttributes(fills: shape.fills, strokes: shape.strokes, svgAttrs: shape.svgAttrs)
        var result = "\n<g\(attrs)>"

        for childId in children {
            result += renderShape(id: childId, objects: objects, originX: originX, originY: originY)
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
        // SVG path commands: M, L, C, S, Q, T, A, Z (uppercase = absolute, lowercase = relative)
        // Only absolute commands need normalization
        var result = ""
        var i = pathData.startIndex
        var isX = true // alternate X/Y for coordinate pairs

        while i < pathData.endIndex {
            let ch = pathData[i]

            if ch.isLetter {
                result.append(ch)
                // Reset coordinate tracking for new command
                isX = true
                // Relative commands (lowercase) don't need offset
                // Z/z has no coordinates
                i = pathData.index(after: i)
                continue
            }

            if ch == "," || ch == " " {
                result.append(ch)
                i = pathData.index(after: i)
                continue
            }

            if ch == "-" || ch == "." || ch.isNumber {
                // Parse number
                var numStr = ""
                var j = i
                // Handle negative sign
                if pathData[j] == "-" {
                    numStr.append("-")
                    j = pathData.index(after: j)
                }
                // Parse digits and decimal
                var hasDot = false
                while j < pathData.endIndex {
                    let c = pathData[j]
                    if c.isNumber {
                        numStr.append(c)
                    } else if c == ".", !hasDot {
                        hasDot = true
                        numStr.append(c)
                    } else {
                        break
                    }
                    j = pathData.index(after: j)
                }

                if let value = Double(numStr) {
                    // Find the last command to check if absolute
                    let lastCmd = findLastCommand(in: pathData, before: i)
                    if let cmd = lastCmd, cmd.isUppercase, cmd != "Z", cmd != "A" {
                        // For A (arc) command, only coordinates 6&7 of each 7-param set need offset
                        // Simplified: offset all X/Y pairs for non-arc absolute commands
                        let offset = isX ? originX : originY
                        result.append(formatNumber(value - offset))
                    } else {
                        result.append(formatNumber(value))
                    }
                    isX.toggle()
                } else {
                    result.append(numStr)
                }
                i = j
                continue
            }

            result.append(ch)
            i = pathData.index(after: i)
        }

        return result
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
