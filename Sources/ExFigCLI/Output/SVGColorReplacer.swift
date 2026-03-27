import Foundation

/// A resolved dark color with optional alpha override.
struct ColorReplacement {
    let hex: String
    let alpha: Double

    /// Whether this replacement changes opacity (not fully opaque).
    var changesOpacity: Bool {
        alpha < 0.999
    }
}

/// Replaces hex colors in SVG content based on a light→dark color map.
///
/// Used by ``VariableModeDarkGenerator`` to create dark SVG variants
/// by substituting resolved light colors with their dark counterparts.
enum SVGColorReplacer {
    /// Replaces hex colors in SVG content using the provided color map.
    ///
    /// Handles both RGB hex replacement and opacity changes. When the dark color
    /// has alpha < 1.0, adds `-opacity` attributes to the SVG elements.
    ///
    /// - Parameters:
    ///   - svgContent: The SVG string to process.
    ///   - colorMap: A mapping of normalized 6-digit lowercase hex (no `#`) to dark replacement.
    /// - Returns: The SVG string with colors replaced.
    static func replaceColors(in svgContent: String, colorMap: [String: ColorReplacement]) -> String {
        guard !colorMap.isEmpty else { return svgContent }

        var result = svgContent

        for (lightHex, replacement) in colorMap {
            result = replaceHex(in: result, lightHex: lightHex, replacement: replacement)
        }

        return result
    }

    // swiftlint:disable function_body_length

    private static func replaceHex(in svg: String, lightHex: String, replacement: ColorReplacement) -> String {
        var result = svg
        let darkHex = replacement.hex

        if replacement.changesOpacity {
            let opacityStr = String(format: "%.2g", replacement.alpha)

            // Attribute style: fill="#aabbcc" → fill="#darkHex" fill-opacity="0"
            result = regexReplace(
                in: result,
                pattern: "(fill|stroke)(\\s*=\\s*[\"'])#\(lightHex)([\"'])",
                template: "$1$2#\(darkHex)$3 $1-opacity=\"\(opacityStr)\""
            )
            // stop-color in gradients: stop-color="#aabbcc" → stop-color="#darkHex" stop-opacity="0"
            result = regexReplace(
                in: result,
                pattern: "(stop-color)(\\s*=\\s*[\"'])#\(lightHex)([\"'])",
                template: "$1$2#\(darkHex)$3 stop-opacity=\"\(opacityStr)\""
            )
            // CSS property style: fill:#aabbcc → fill:#darkHex;fill-opacity:0
            result = regexReplace(
                in: result,
                pattern: "(fill|stroke)(\\s*:\\s*)#\(lightHex)",
                template: "$1$2#\(darkHex);$1-opacity:\(opacityStr)"
            )
            result = regexReplace(
                in: result,
                pattern: "(stop-color)(\\s*:\\s*)#\(lightHex)",
                template: "$1$2#\(darkHex);stop-opacity:\(opacityStr)"
            )
        } else {
            // Simple hex-only replacement (no opacity change)
            let replacements: [(pattern: String, template: String)] = [
                (
                    "(fill|stroke|stop-color|flood-color|lighting-color)(\\s*=\\s*[\"'])#\(lightHex)([\"'])",
                    "$1$2#\(darkHex)$3"
                ),
                (
                    "(fill|stroke|stop-color|flood-color|lighting-color)(\\s*:\\s*)#\(lightHex)",
                    "$1$2#\(darkHex)"
                ),
            ]
            for (pattern, template) in replacements {
                result = regexReplace(in: result, pattern: pattern, template: template)
            }
        }

        return result
    }

    // swiftlint:enable function_body_length

    private static func regexReplace(in string: String, pattern: String, template: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(string.startIndex..., in: string)
            return regex.stringByReplacingMatches(in: string, range: range, withTemplate: template)
        } catch {
            assertionFailure("Invalid regex pattern: \(pattern), error: \(error)")
            return string
        }
    }

    /// Normalizes a ``FigmaAPI.PaintColor`` (RGBA 0–1) to a 6-digit lowercase hex string without `#`.
    static func normalizeColor(r: Double, g: Double, b: Double) -> String {
        let ri = min(255, max(0, Int(round(r * 255))))
        let gi = min(255, max(0, Int(round(g * 255))))
        let bi = min(255, max(0, Int(round(b * 255))))
        return String(format: "%02x%02x%02x", ri, gi, bi)
    }
}
