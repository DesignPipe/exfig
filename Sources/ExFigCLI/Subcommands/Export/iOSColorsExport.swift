import ExFig_iOS
import ExFigCore
import Foundation
import XcodeExport

// MARK: - iOS Colors Export

extension ExFigCommand.ExportColors {
    // MARK: - Xcode Entry Export

    func exportXcodeColorsEntry(
        colorPairs: [AssetPair<Color>],
        entry: iOSColorsEntry,
        ios: iOS.iOSConfig,
        ui: TerminalUI
    ) throws {
        var colorsURL: URL?
        if entry.useColorAssets {
            if let folder = entry.assetsFolder {
                guard let xcassetsPath = ios.xcassetsPath else {
                    throw ExFigError
                        .configurationError("xcassetsPath is required for iOS colors export with useColorAssets")
                }
                colorsURL = URL(fileURLWithPath: xcassetsPath).appendingPathComponent(folder)
            } else {
                throw ExFigError.colorsAssetsFolderNotSpecified
            }
        }

        let output = XcodeColorsOutput(
            assetsColorsURL: colorsURL,
            assetsInMainBundle: ios.xcassetsInMainBundle,
            assetsInSwiftPackage: ios.xcassetsInSwiftPackage,
            resourceBundleNames: ios.resourceBundleNames,
            addObjcAttribute: ios.addObjcAttribute,
            colorSwiftURL: entry.colorSwiftURL,
            swiftuiColorSwiftURL: entry.swiftuiColorSwiftURL,
            groupUsingNamespace: entry.groupUsingNamespace,
            templatesPath: ios.templatesPath.map { URL(fileURLWithPath: $0) }
        )

        let exporter = XcodeColorExporter(output: output)
        let files = try exporter.export(colorPairs: colorPairs)

        if entry.useColorAssets, let url = colorsURL {
            try? FileManager.default.removeItem(atPath: url.path)
        }

        try ExFigCommand.fileWriter.write(files: files)

        guard ios.xcassetsInSwiftPackage == false else {
            return
        }

        #if canImport(XcodeProj)
            do {
                let xcodeProject = try XcodeProjectWriter(
                    xcodeProjPath: ios.xcodeprojPath,
                    target: ios.target
                )
                try files.forEach { file in
                    if file.destination.file.pathExtension == "swift" {
                        try xcodeProject.addFileReferenceToXcodeProj(file.destination.url)
                    }
                }
                try xcodeProject.save()
            } catch {
                ui.warning(.xcodeProjectUpdateFailed(detail: error.localizedDescription))
            }
        #endif
    }
}
