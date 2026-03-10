import ExFigCore
import Foundation

public final class XcodeColorExporter: XcodeExporterBase {
    enum Error: LocalizedError {
        case missingAssetsFolderName

        var errorDescription: String? {
            "assetsFolderProvidesNamespace requires a non-empty assetsFolder name"
        }

        var recoverySuggestion: String? {
            "Set assetsFolder in your iOS colors entry when using assetsFolderProvidesNamespace"
        }
    }

    private let output: XcodeColorsOutput

    public init(output: XcodeColorsOutput) {
        self.output = output
    }

    public func export(colorPairs: [AssetPair<Color>]) throws -> [FileContents] {
        if output.assetsFolderProvidesNamespace {
            guard let name = output.assetsFolderName, !name.isEmpty else {
                throw Error.missingAssetsFolderName
            }
        }

        var files: [FileContents] = []

        // UIKit UIColor extension
        if let url = output.colorSwiftURL {
            try files.append(makeUIColorExtensionFileContents(for: colorPairs, file: url))
        }

        // SwiftUI Color extension
        if let url = output.swiftuiColorSwiftURL {
            try files.append(makeColorExtensionFileContents(for: colorPairs, file: url))
        }

        guard let assetCatalogURL = output.assetsColorsURL else { return files }

        // Assets.xcassets/Colors/Contents.json
        if output.assetsFolderProvidesNamespace {
            files.append(makeXcodeNamespaceFileContents(directoryURL: assetCatalogURL))
        } else {
            files.append(makeXcodeEmptyFileContents(directoryURL: assetCatalogURL))
        }

        // Assets.xcassets/Colors/***.colorset/Contents.json
        try files.append(contentsOf: makeAssets(for: colorPairs, assetCatalogURL: assetCatalogURL))

        return files
    }

    private func makeUIColorExtensionFileContents(
        for colorPairs: [AssetPair<Color>],
        file: URL
    ) throws -> FileContents {
        let contents = try makeUIColorExtensionContents(colorPairs)
        return try makeFileContents(for: contents, url: file)
    }

    private func makeColorExtensionFileContents(for colorPairs: [AssetPair<Color>], file: URL) throws -> FileContents {
        let contents = try makeColorExtensionContents(colorPairs)
        return try makeFileContents(for: contents, url: file)
    }

    private func makeColorExtensionContents(_ colorPairs: [AssetPair<Color>]) throws -> String {
        let useAssets = output.assetsColorsURL != nil

        let colors: [[String: Any]] = colorPairs.sorted { $0.light.name < $1.light.name }.map { colorPair in
            var obj: [String: Any] = [:]

            let name = normalizeName(colorPair.light.name)
            obj["name"] = name
            obj["originalName"] = assetFolderPrefixed(colorPair.light.originalName)

            if !useAssets {
                let lightComponents = colorPair.light.toRgbComponents()

                obj["hasDarkVariant"] = false
                obj["red"] = lightComponents.red
                obj["green"] = lightComponents.green
                obj["blue"] = lightComponents.blue
                obj["alpha"] = lightComponents.alpha
            }

            return obj
        }

        let context: [String: Any] = [
            "assetsInSwiftPackage": output.assetsInSwiftPackage,
            "resourceBundleNames": output.resourceBundleNames ?? [],
            "colorFromAssetCatalog": useAssets,
            "assetsInMainBundle": output.assetsInMainBundle,
            "useNamespace": output.groupUsingNamespace || output.assetsFolderProvidesNamespace,
            "colors": colors,
        ]

        let fullContext = try contextWithHeaderAndBundle(context, templatesPath: output.templatesPath)
        return try renderTemplate(
            name: "Color+extension.swift.jinja",
            context: fullContext,
            templatesPath: output.templatesPath
        )
    }

    private func makeUIColorExtensionContents(_ colorPairs: [AssetPair<Color>]) throws -> String {
        let useAssets = output.assetsColorsURL != nil
        let colors: [[String: Any]] = colorPairs.sorted { $0.light.name < $1.light.name }.map { colorPair in
            let name = normalizeName(colorPair.light.name)

            var obj: [String: Any] = [:]
            obj["name"] = name
            obj["originalName"] = assetFolderPrefixed(colorPair.light.originalName)

            if !useAssets {
                let lightComponents = colorPair.light.toRgbComponents()

                if let darkComponents = colorPair.dark?.toRgbComponents() {
                    obj["light"] = [
                        "name": name,
                        "red": lightComponents.red,
                        "green": lightComponents.green,
                        "blue": lightComponents.blue,
                        "alpha": lightComponents.alpha,
                    ]
                    obj["dark"] = [
                        "name": name,
                        "red": darkComponents.red,
                        "green": darkComponents.green,
                        "blue": darkComponents.blue,
                        "alpha": darkComponents.alpha,
                    ]
                    obj["hasDarkVariant"] = true
                } else {
                    obj["hasDarkVariant"] = false
                    obj["red"] = lightComponents.red
                    obj["green"] = lightComponents.green
                    obj["blue"] = lightComponents.blue
                    obj["alpha"] = lightComponents.alpha
                }
            }
            return obj
        }

        let context: [String: Any] = [
            "assetsInSwiftPackage": output.assetsInSwiftPackage,
            "resourceBundleNames": output.resourceBundleNames ?? [],
            "addObjcPrefix": output.addObjcAttribute,
            "colorFromAssetCatalog": useAssets,
            "assetsInMainBundle": output.assetsInMainBundle,
            "useNamespace": output.groupUsingNamespace || output.assetsFolderProvidesNamespace,
            "colors": colors,
        ]

        let fullContext = try contextWithHeaderAndBundle(context, templatesPath: output.templatesPath)
        return try renderTemplate(
            name: "UIColor+extension.swift.jinja",
            context: fullContext,
            templatesPath: output.templatesPath
        )
    }

    private func assetFolderPrefixed(_ originalName: String) -> String {
        if output.assetsFolderProvidesNamespace, let prefix = output.assetsFolderName {
            return "\(prefix)/\(originalName)"
        }
        return originalName
    }

    private func makeXcodeNamespaceFileContents(directoryURL: URL) -> FileContents {
        let contentsJson = XcodeFolderNamespaceContents()
        return FileContents(
            destination: Destination(directory: directoryURL, file: contentsJson.fileURL),
            data: contentsJson.data
        )
    }

    private func makeXcodeEmptyFileContents(directoryURL: URL) -> FileContents {
        let contentsJson = XcodeEmptyContents()
        return FileContents(
            destination: Destination(directory: directoryURL, file: contentsJson.fileURL),
            data: contentsJson.data
        )
    }

    // swiftlint:disable:next function_body_length
    private func makeAssets(
        for colorPairs: [AssetPair<Color>],
        assetCatalogURL: URL
    ) throws -> [FileContents] {
        try colorPairs.sorted { $0.light.name < $1.light.name }.flatMap { colorPair -> [FileContents] in
            var files = [FileContents]()

            var name = colorPair.light.name
            var assetsColorsURL = assetCatalogURL

            if output.groupUsingNamespace,
               let lastName = colorPair.light.originalName.split(separator: "/").last
            {
                name = String(lastName)

                colorPair.light.originalName.split(separator: "/")
                    .dropLast()
                    .map { String($0) }
                    .forEach {
                        assetsColorsURL.appendPathComponent($0, isDirectory: true)

                        let contentsJson = XcodeFolderNamespaceContents()
                        files.append(FileContents(
                            destination: Destination(directory: assetsColorsURL, file: contentsJson.fileURL),
                            data: contentsJson.data
                        ))
                    }
            }

            let dirURL = assetsColorsURL.appendingPathComponent("\(name).colorset")

            var colors: [XcodeAssetContents.ColorData] = [
                XcodeAssetContents.ColorData(
                    appearances: nil,
                    color: XcodeAssetContents.ColorInfo(
                        components: colorPair.light.toHexComponents()
                    )
                ),
            ]
            if let darkColor = colorPair.dark {
                colors.append(
                    XcodeAssetContents.ColorData(
                        appearances: [.dark],
                        color: XcodeAssetContents.ColorInfo(
                            components: darkColor.toHexComponents()
                        )
                    )
                )
            }
            if let lightHCColor = colorPair.lightHC {
                colors.append(
                    XcodeAssetContents.ColorData(
                        appearances: [.highContrast],
                        color: XcodeAssetContents.ColorInfo(
                            components: lightHCColor.toHexComponents()
                        )
                    )
                )
            }
            if let darkHCColor = colorPair.darkHC {
                colors.append(
                    XcodeAssetContents.ColorData(
                        appearances: [.dark, .highContrast],
                        color: XcodeAssetContents.ColorInfo(
                            components: darkHCColor.toHexComponents()
                        )
                    )
                )
            }

            // Contents.json
            try files.append(
                makeXcodeAssetFileContents(contents: XcodeAssetContents(colors: colors), directory: dirURL)
            )
            return files
        }
    }

    private func makeXcodeAssetFileContents(contents: XcodeAssetContents, directory: URL) throws -> FileContents {
        let data = try JSONCodec.encodePrettySorted(contents)
        // swiftlint:disable:next force_unwrapping
        let fileURL = URL(string: "Contents.json")!
        return FileContents(
            destination: Destination(directory: directory, file: fileURL),
            data: data
        )
    }
}

private extension Color {
    func toHexComponents() -> XcodeAssetContents.Components {
        let red = "0x\(doubleToHex(red))"
        let green = "0x\(doubleToHex(green))"
        let blue = "0x\(doubleToHex(blue))"
        let alpha = String(format: "%.3F", arguments: [alpha])
        return XcodeAssetContents.Components(red: red, alpha: alpha, green: green, blue: blue)
    }

    func doubleToHex(_ double: Double) -> String {
        String(format: "%02X", arguments: [Int((double * 255).rounded())])
    }

    func toRgbComponents() -> XcodeAssetContents.Components {
        let red = String(format: "%.3F", arguments: [red])
        let green = String(format: "%.3F", arguments: [green])
        let blue = String(format: "%.3F", arguments: [blue])
        let alpha = String(format: "%.3F", arguments: [alpha])
        return XcodeAssetContents.Components(red: red, alpha: alpha, green: green, blue: blue)
    }
}
