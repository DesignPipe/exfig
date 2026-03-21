import ExFigCore
import Foundation
import PenpotAPI

struct PenpotColorsSource: ColorsSource {
    let ui: TerminalUI

    func loadColors(from input: ColorsSourceInput) async throws -> ColorsLoadOutput {
        guard let config = input.sourceConfig as? PenpotColorsConfig else {
            throw ExFigError.configurationError(
                "PenpotColorsSource requires PenpotColorsConfig, got \(type(of: input.sourceConfig))"
            )
        }

        let client = try Self.makeClient(baseURL: config.baseURL)
        let fileResponse = try await client.request(GetFileEndpoint(fileId: config.fileId))

        guard let penpotColors = fileResponse.data.colors else {
            return ColorsLoadOutput(light: [])
        }

        var colors: [Color] = []

        for (_, penpotColor) in penpotColors {
            // Skip gradient/image fills (no solid hex)
            guard let hex = penpotColor.color else { continue }

            // Apply path filter
            if let pathFilter = config.pathFilter {
                guard let path = penpotColor.path, path.hasPrefix(pathFilter) else {
                    continue
                }
            }

            guard let rgba = Self.hexToRGBA(hex: hex, opacity: penpotColor.opacity ?? 1.0) else {
                ui.warning("Color '\(penpotColor.name)' has invalid hex value '\(hex)' — skipping")
                continue
            }

            let name = if let path = penpotColor.path {
                path + "/" + penpotColor.name
            } else {
                penpotColor.name
            }

            colors.append(Color(
                name: name,
                platform: nil,
                red: rgba.red,
                green: rgba.green,
                blue: rgba.blue,
                alpha: rgba.alpha
            ))
        }

        // Penpot has no mode-based variants — light only
        return ColorsLoadOutput(light: colors)
    }

    // MARK: - Internal

    static func makeClient(baseURL: String) throws -> BasePenpotClient {
        guard let token = ProcessInfo.processInfo.environment["PENPOT_ACCESS_TOKEN"], !token.isEmpty else {
            throw ExFigError.configurationError(
                "PENPOT_ACCESS_TOKEN environment variable is required for Penpot source"
            )
        }
        return BasePenpotClient(accessToken: token, baseURL: baseURL)
    }

    static func hexToRGBA(hex: String, opacity: Double)
        -> (red: Double, green: Double, blue: Double, alpha: Double)?
    {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        guard hexString.count == 6, let hexValue = UInt64(hexString, radix: 16) else {
            return nil
        }

        let red = Double((hexValue >> 16) & 0xFF) / 255.0
        let green = Double((hexValue >> 8) & 0xFF) / 255.0
        let blue = Double(hexValue & 0xFF) / 255.0

        return (red: red, green: green, blue: blue, alpha: opacity)
    }
}
