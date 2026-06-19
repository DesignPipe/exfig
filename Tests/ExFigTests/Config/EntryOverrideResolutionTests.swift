// swiftlint:disable type_name file_length

import ExFig_Android
import ExFig_Flutter
import ExFig_iOS
import ExFig_Web
import ExFigCore
import Foundation
import XCTest

// MARK: - iOS Entry Override Resolution

final class iOSEntryOverrideResolutionTests: XCTestCase {
    // MARK: - xcassetsPath

    func testIconsEntry_xcassetsPathOverride_resolvesEntryValue() throws {
        let entry = try makeIOSIconsEntry(xcassetsPath: "/custom/path.xcassets")
        let fallback = URL(fileURLWithPath: "/default/path.xcassets")

        let resolved = entry.resolvedXcassetsPath(fallback: fallback)

        XCTAssertEqual(resolved?.path, "/custom/path.xcassets")
    }

    func testIconsEntry_xcassetsPathNil_fallsBackToConfig() throws {
        let entry = try makeIOSIconsEntry()
        let fallback = URL(fileURLWithPath: "/default/path.xcassets")

        let resolved = entry.resolvedXcassetsPath(fallback: fallback)

        XCTAssertEqual(resolved, fallback)
    }

    func testImagesEntry_xcassetsPathOverride_resolvesEntryValue() throws {
        let entry = try makeIOSImagesEntry(xcassetsPath: "/images/custom.xcassets")
        let fallback = URL(fileURLWithPath: "/default/images.xcassets")

        let resolved = entry.resolvedXcassetsPath(fallback: fallback)

        XCTAssertEqual(resolved?.path, "/images/custom.xcassets")
    }

    func testImagesEntry_xcassetsPathNil_fallsBackToConfig() throws {
        let entry = try makeIOSImagesEntry()
        let fallback = URL(fileURLWithPath: "/default/images.xcassets")

        let resolved = entry.resolvedXcassetsPath(fallback: fallback)

        XCTAssertEqual(resolved, fallback)
    }

    // MARK: - templatesPath

    func testIconsEntry_templatesPathOverride_resolvesEntryValue() throws {
        let entry = try makeIOSIconsEntry(templatesPath: "/custom/templates")
        let fallback = URL(fileURLWithPath: "/default/templates")

        let resolved = entry.resolvedTemplatesPath(fallback: fallback)

        XCTAssertEqual(resolved?.path, "/custom/templates")
    }

    func testIconsEntry_templatesPathNil_fallsBackToConfig() throws {
        let entry = try makeIOSIconsEntry()
        let fallback = URL(fileURLWithPath: "/default/templates")

        let resolved = entry.resolvedTemplatesPath(fallback: fallback)

        XCTAssertEqual(resolved, fallback)
    }

    // MARK: - Helpers

    private func makeIOSIconsEntry(
        xcassetsPath: String? = nil,
        templatesPath: String? = nil
    ) throws -> iOSIconsEntry {
        var fields = [String]()
        fields.append("\"format\": \"svg\"")
        fields.append("\"assetsFolder\": \"Icons\"")
        fields.append("\"nameStyle\": \"camelCase\"")
        if let xcassetsPath { fields.append("\"xcassetsPath\": \"\(xcassetsPath)\"") }
        if let templatesPath { fields.append("\"templatesPath\": \"\(templatesPath)\"") }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(iOSIconsEntry.self, from: Data(json.utf8))
    }

    private func makeIOSImagesEntry(
        xcassetsPath: String? = nil
    ) throws -> iOSImagesEntry {
        var fields = [String]()
        fields.append("\"nameStyle\": \"camelCase\"")
        fields.append("\"assetsFolder\": \"Images\"")
        if let xcassetsPath { fields.append("\"xcassetsPath\": \"\(xcassetsPath)\"") }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(iOSImagesEntry.self, from: Data(json.utf8))
    }

    // MARK: - SVG→WebP support

    func testImagesEntry_webpOutputFormat_bridgesToCoreWebp() throws {
        let json = """
        { "nameStyle": "camelCase", "assetsFolder": "Images", \
        "sourceFormat": "svg", "outputFormat": "webp" }
        """
        let entry = try JSONDecoder().decode(iOSImagesEntry.self, from: Data(json.utf8))

        XCTAssertEqual(entry.effectiveSourceFormat, .svg)
        XCTAssertEqual(entry.effectiveOutputFormat, .webp)
    }

    func testImagesEntry_webpOptions_bridgeToConverterOptions() throws {
        let json = """
        { "nameStyle": "camelCase", "assetsFolder": "Images", \
        "outputFormat": "webp", \
        "webpOptions": { "encoding": "lossless", "quality": 80 } }
        """
        let entry = try JSONDecoder().decode(iOSImagesEntry.self, from: Data(json.utf8))

        let opts = entry.webpConverterOptions
        XCTAssertEqual(opts?.lossless, true)
        XCTAssertEqual(opts?.quality, 80)
    }

    func testImagesEntry_noWebpOptions_returnsNilConverterOptions() throws {
        let entry = try makeIOSImagesEntry()
        XCTAssertNil(entry.webpConverterOptions)
    }
}

// MARK: - Android Entry Override Resolution

final class AndroidEntryOverrideResolutionTests: XCTestCase {
    func testIconsEntry_mainResOverride_resolvesEntryValue() throws {
        let entry = try makeAndroidIconsEntry(mainRes: "/custom/res")
        let fallback = URL(fileURLWithPath: "/default/res")

        let resolved = entry.resolvedMainRes(fallback: fallback)

        XCTAssertEqual(resolved.path, "/custom/res")
    }

    func testIconsEntry_mainResNil_fallsBackToConfig() throws {
        let entry = try makeAndroidIconsEntry()
        let fallback = URL(fileURLWithPath: "/default/res")

        let resolved = entry.resolvedMainRes(fallback: fallback)

        XCTAssertEqual(resolved, fallback)
    }

    // MARK: - effectiveCodeConnectPackageName

    func testIconsEntry_bothPackageNames_prefersCodeConnect() throws {
        let entry = try makeAndroidIconsEntry(
            composePackageName: "com.compose",
            codeConnectPackageName: "com.codeconnect"
        )

        XCTAssertEqual(entry.effectiveCodeConnectPackageName, "com.codeconnect")
    }

    func testIconsEntry_onlyComposePackageName_fallsBack() throws {
        let entry = try makeAndroidIconsEntry(composePackageName: "com.compose")

        XCTAssertEqual(entry.effectiveCodeConnectPackageName, "com.compose")
    }

    func testIconsEntry_onlyCodeConnectPackageName_returnsIt() throws {
        let entry = try makeAndroidIconsEntry(codeConnectPackageName: "com.codeconnect")

        XCTAssertEqual(entry.effectiveCodeConnectPackageName, "com.codeconnect")
    }

    func testIconsEntry_bothNil_returnsNil() throws {
        let entry = try makeAndroidIconsEntry()

        XCTAssertNil(entry.effectiveCodeConnectPackageName)
    }

    // MARK: - ImagesEntry mainRes

    func testImagesEntry_mainResOverride_resolvesEntryValue() throws {
        let entry = try makeAndroidImagesEntry(mainRes: "/images/res")
        let fallback = URL(fileURLWithPath: "/default/res")

        let resolved = entry.resolvedMainRes(fallback: fallback)

        XCTAssertEqual(resolved.path, "/images/res")
    }

    // MARK: - Helpers

    private func makeAndroidIconsEntry(
        mainRes: String? = nil,
        composePackageName: String? = nil,
        codeConnectPackageName: String? = nil
    ) throws -> AndroidIconsEntry {
        var fields = [String]()
        fields.append("\"output\": \"drawable\"")
        if let mainRes { fields.append("\"mainRes\": \"\(mainRes)\"") }
        if let composePackageName { fields.append("\"composePackageName\": \"\(composePackageName)\"") }
        if let codeConnectPackageName { fields.append("\"codeConnectPackageName\": \"\(codeConnectPackageName)\"") }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(AndroidIconsEntry.self, from: Data(json.utf8))
    }

    private func makeAndroidImagesEntry(
        mainRes: String? = nil
    ) throws -> AndroidImagesEntry {
        var fields = [String]()
        fields.append("\"format\": \"png\"")
        fields.append("\"output\": \"drawable\"")
        if let mainRes { fields.append("\"mainRes\": \"\(mainRes)\"") }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(AndroidImagesEntry.self, from: Data(json.utf8))
    }
}

// MARK: - Flutter Entry Override Resolution

final class FlutterEntryOverrideResolutionTests: XCTestCase {
    func testIconsEntry_templatesPathOverride_resolvesEntryValue() throws {
        let entry = try makeFlutterIconsEntry(templatesPath: "/custom/templates")
        let fallback = URL(fileURLWithPath: "/default/templates")

        let resolved = entry.resolvedTemplatesPath(fallback: fallback)

        XCTAssertEqual(resolved?.path, "/custom/templates")
    }

    func testIconsEntry_templatesPathNil_fallsBackToConfig() throws {
        let entry = try makeFlutterIconsEntry()
        let fallback = URL(fileURLWithPath: "/default/templates")

        let resolved = entry.resolvedTemplatesPath(fallback: fallback)

        XCTAssertEqual(resolved, fallback)
    }

    // MARK: - Helpers

    private func makeFlutterIconsEntry(
        templatesPath: String? = nil
    ) throws -> FlutterIconsEntry {
        var fields = [String]()
        fields.append("\"output\": \"assets/icons\"")
        if let templatesPath { fields.append("\"templatesPath\": \"\(templatesPath)\"") }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(FlutterIconsEntry.self, from: Data(json.utf8))
    }
}

// MARK: - Web Entry Override Resolution

final class WebEntryOverrideResolutionTests: XCTestCase {
    func testIconsEntry_templatesPathOverride_resolvesEntryValue() throws {
        let entry = try makeWebIconsEntry(templatesPath: "/custom/templates")
        let fallback = URL(fileURLWithPath: "/default/templates")

        let resolved = entry.resolvedTemplatesPath(fallback: fallback)

        XCTAssertEqual(resolved?.path, "/custom/templates")
    }

    func testIconsEntry_templatesPathNil_fallsBackToConfig() throws {
        let entry = try makeWebIconsEntry()
        let fallback = URL(fileURLWithPath: "/default/templates")

        let resolved = entry.resolvedTemplatesPath(fallback: fallback)

        XCTAssertEqual(resolved, fallback)
    }

    // MARK: - Helpers

    private func makeWebIconsEntry(templatesPath: String? = nil) throws -> WebIconsEntry {
        var fields = [String]()
        fields.append("\"outputDirectory\": \"dist/icons\"")
        if let templatesPath { fields.append("\"templatesPath\": \"\(templatesPath)\"") }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(WebIconsEntry.self, from: Data(json.utf8))
    }

    private func makeWebImagesEntry() throws -> WebImagesEntry {
        let json = "{ \"outputDirectory\": \"dist/images\" }"
        return try JSONDecoder().decode(WebImagesEntry.self, from: Data(json.utf8))
    }
}

// MARK: - Empty String Edge Cases

final class EmptyStringOverrideTests: XCTestCase {
    func testIconsEntry_xcassetsPathEmpty_treatedAsOverride() throws {
        let entry = try makeIOSIconsEntry(xcassetsPath: "")
        let fallback = URL(fileURLWithPath: "/default/path.xcassets")

        let resolved = entry.resolvedXcassetsPath(fallback: fallback)

        // Empty string is a non-nil override — does NOT fall back
        XCTAssertNotEqual(resolved, fallback)
        XCTAssertNotNil(resolved)
    }

    func testIconsEntry_figmaFileIdEmpty_treatedAsOverride() throws {
        let entry = try makeIOSIconsEntry(figmaFileId: "")

        let input = entry.iconsSourceInput()

        // Empty string is a non-nil override — does NOT fall back to global
        XCTAssertEqual(input.figmaFileId, "")
    }

    func testImagesEntry_figmaFileIdEmpty_passedToSourceInput() throws {
        let entry = try makeIOSImagesEntry(figmaFileId: "")

        let input = entry.imagesSourceInput()

        XCTAssertEqual(input.figmaFileId, "")
    }

    // MARK: - Helpers

    private func makeIOSIconsEntry(
        xcassetsPath: String? = nil,
        figmaFileId: String? = nil
    ) throws -> iOSIconsEntry {
        var fields = [String]()
        fields.append("\"format\": \"svg\"")
        fields.append("\"assetsFolder\": \"Icons\"")
        fields.append("\"nameStyle\": \"camelCase\"")
        if let xcassetsPath { fields.append("\"xcassetsPath\": \"\(xcassetsPath)\"") }
        if let figmaFileId { fields.append("\"figmaFileId\": \"\(figmaFileId)\"") }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(iOSIconsEntry.self, from: Data(json.utf8))
    }

    private func makeIOSImagesEntry(figmaFileId: String? = nil) throws -> iOSImagesEntry {
        var fields = [String]()
        fields.append("\"nameStyle\": \"camelCase\"")
        fields.append("\"assetsFolder\": \"Images\"")
        if let figmaFileId { fields.append("\"figmaFileId\": \"\(figmaFileId)\"") }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(iOSImagesEntry.self, from: Data(json.utf8))
    }
}

// MARK: - ColorsEntry Override Resolution

final class ColorsEntryOverrideResolutionTests: XCTestCase {
    // MARK: - iOS Colors

    func testIOSColorsEntry_xcassetsPathOverride_resolvesEntryValue() throws {
        let entry = try makeIOSColorsEntry(xcassetsPath: "/custom/Colors.xcassets")
        let fallback = URL(fileURLWithPath: "/default/Colors.xcassets")

        let resolved = entry.resolvedXcassetsPath(fallback: fallback)

        XCTAssertEqual(resolved?.path, "/custom/Colors.xcassets")
    }

    func testIOSColorsEntry_xcassetsPathNil_fallsBackToConfig() throws {
        let entry = try makeIOSColorsEntry()
        let fallback = URL(fileURLWithPath: "/default/Colors.xcassets")

        let resolved = entry.resolvedXcassetsPath(fallback: fallback)

        XCTAssertEqual(resolved, fallback)
    }

    func testIOSColorsEntry_templatesPathOverride_resolvesEntryValue() throws {
        let entry = try makeIOSColorsEntry(templatesPath: "/custom/templates")
        let fallback = URL(fileURLWithPath: "/default/templates")

        let resolved = entry.resolvedTemplatesPath(fallback: fallback)

        XCTAssertEqual(resolved?.path, "/custom/templates")
    }

    func testIOSColorsEntry_templatesPathNil_fallsBackToConfig() throws {
        let entry = try makeIOSColorsEntry()
        let fallback = URL(fileURLWithPath: "/default/templates")

        let resolved = entry.resolvedTemplatesPath(fallback: fallback)

        XCTAssertEqual(resolved, fallback)
    }

    // MARK: - Android Colors

    func testAndroidColorsEntry_mainResOverride_resolvesEntryValue() throws {
        let entry = try makeAndroidColorsEntry(mainRes: "/custom/res")
        let fallback = URL(fileURLWithPath: "/default/res")

        let resolved = entry.resolvedMainRes(fallback: fallback)

        XCTAssertEqual(resolved.path, "/custom/res")
    }

    func testAndroidColorsEntry_mainResNil_fallsBackToConfig() throws {
        let entry = try makeAndroidColorsEntry()
        let fallback = URL(fileURLWithPath: "/default/res")

        let resolved = entry.resolvedMainRes(fallback: fallback)

        XCTAssertEqual(resolved, fallback)
    }

    func testAndroidColorsEntry_mainSrcOverride_resolvesEntryValue() throws {
        let entry = try makeAndroidColorsEntry(mainSrc: "/custom/src")
        let fallback = URL(fileURLWithPath: "/default/src")

        let resolved = entry.resolvedMainSrc(fallback: fallback)

        XCTAssertEqual(resolved?.path, "/custom/src")
    }

    func testAndroidColorsEntry_mainSrcNil_fallsBackToConfig() throws {
        let entry = try makeAndroidColorsEntry()
        let fallback = URL(fileURLWithPath: "/default/src")

        let resolved = entry.resolvedMainSrc(fallback: fallback)

        XCTAssertEqual(resolved, fallback)
    }

    func testAndroidColorsEntry_templatesPathOverride_resolvesEntryValue() throws {
        let entry = try makeAndroidColorsEntry(templatesPath: "/custom/templates")
        let fallback = URL(fileURLWithPath: "/default/templates")

        let resolved = entry.resolvedTemplatesPath(fallback: fallback)

        XCTAssertEqual(resolved?.path, "/custom/templates")
    }

    // MARK: - Flutter Colors

    func testFlutterColorsEntry_templatesPathOverride_resolvesEntryValue() throws {
        let entry = try makeFlutterColorsEntry(templatesPath: "/custom/templates")
        let fallback = URL(fileURLWithPath: "/default/templates")

        let resolved = entry.resolvedTemplatesPath(fallback: fallback)

        XCTAssertEqual(resolved?.path, "/custom/templates")
    }

    func testFlutterColorsEntry_templatesPathNil_fallsBackToConfig() throws {
        let entry = try makeFlutterColorsEntry()
        let fallback = URL(fileURLWithPath: "/default/templates")

        let resolved = entry.resolvedTemplatesPath(fallback: fallback)

        XCTAssertEqual(resolved, fallback)
    }

    // MARK: - Web Colors

    func testWebColorsEntry_outputOverride_resolvesEntryValue() throws {
        let entry = try makeWebColorsEntry(output: "/custom/output")
        let fallback = URL(fileURLWithPath: "/default/output")

        let resolved = entry.resolvedOutput(fallback: fallback)

        XCTAssertEqual(resolved.path, "/custom/output")
    }

    func testWebColorsEntry_outputNil_fallsBackToConfig() throws {
        let entry = try makeWebColorsEntry()
        let fallback = URL(fileURLWithPath: "/default/output")

        let resolved = entry.resolvedOutput(fallback: fallback)

        XCTAssertEqual(resolved, fallback)
    }

    func testWebColorsEntry_templatesPathOverride_resolvesEntryValue() throws {
        let entry = try makeWebColorsEntry(templatesPath: "/custom/templates")
        let fallback = URL(fileURLWithPath: "/default/templates")

        let resolved = entry.resolvedTemplatesPath(fallback: fallback)

        XCTAssertEqual(resolved?.path, "/custom/templates")
    }

    func testWebColorsEntry_templatesPathNil_fallsBackToConfig() throws {
        let entry = try makeWebColorsEntry()
        let fallback = URL(fileURLWithPath: "/default/templates")

        let resolved = entry.resolvedTemplatesPath(fallback: fallback)

        XCTAssertEqual(resolved, fallback)
    }

    // MARK: - Helpers

    private func makeIOSColorsEntry(
        xcassetsPath: String? = nil,
        templatesPath: String? = nil
    ) throws -> iOSColorsEntry {
        var fields = [String]()
        fields.append("\"nameStyle\": \"camelCase\"")
        fields.append("\"useColorAssets\": true")
        if let xcassetsPath { fields.append("\"xcassetsPath\": \"\(xcassetsPath)\"") }
        if let templatesPath { fields.append("\"templatesPath\": \"\(templatesPath)\"") }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(iOSColorsEntry.self, from: Data(json.utf8))
    }

    private func makeAndroidColorsEntry(
        mainRes: String? = nil,
        mainSrc: String? = nil,
        templatesPath: String? = nil
    ) throws -> AndroidColorsEntry {
        var fields = [String]()
        if let mainRes { fields.append("\"mainRes\": \"\(mainRes)\"") }
        if let mainSrc { fields.append("\"mainSrc\": \"\(mainSrc)\"") }
        if let templatesPath { fields.append("\"templatesPath\": \"\(templatesPath)\"") }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(AndroidColorsEntry.self, from: Data(json.utf8))
    }

    private func makeFlutterColorsEntry(
        templatesPath: String? = nil
    ) throws -> FlutterColorsEntry {
        var fields = [String]()
        if let templatesPath { fields.append("\"templatesPath\": \"\(templatesPath)\"") }
        let json = fields.isEmpty ? "{}" : "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(FlutterColorsEntry.self, from: Data(json.utf8))
    }

    private func makeWebColorsEntry(
        output: String? = nil,
        templatesPath: String? = nil
    ) throws -> WebColorsEntry {
        var fields = [String]()
        if let output { fields.append("\"output\": \"\(output)\"") }
        if let templatesPath { fields.append("\"templatesPath\": \"\(templatesPath)\"") }
        let json = fields.isEmpty ? "{}" : "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(WebColorsEntry.self, from: Data(json.utf8))
    }
}

// MARK: - Source Input figmaFileId Propagation

final class SourceInputFigmaFileIdTests: XCTestCase {
    func testIOSIconsEntry_figmaFileId_passedToSourceInput() throws {
        let entry = try makeIOSIconsEntry(figmaFileId: "ios-icons-file")

        let input = entry.iconsSourceInput()

        XCTAssertEqual(input.figmaFileId, "ios-icons-file")
    }

    func testIOSIconsEntry_figmaFileIdNil_sourceInputHasNil() throws {
        let entry = try makeIOSIconsEntry()

        let input = entry.iconsSourceInput()

        XCTAssertNil(input.figmaFileId)
    }

    func testIOSImagesEntry_figmaFileId_passedToSourceInput() throws {
        let entry = try makeIOSImagesEntry(figmaFileId: "ios-images-file")

        let input = entry.imagesSourceInput()

        XCTAssertEqual(input.figmaFileId, "ios-images-file")
    }

    func testAndroidIconsEntry_figmaFileId_passedToSourceInput() throws {
        let entry = try makeAndroidIconsEntry(figmaFileId: "android-icons-file")

        let input = entry.iconsSourceInput()

        XCTAssertEqual(input.figmaFileId, "android-icons-file")
    }

    func testAndroidImagesEntry_figmaFileId_passedToSourceInput() throws {
        let entry = try makeAndroidImagesEntry(figmaFileId: "android-images-file")

        let input = entry.imagesSourceInput()

        XCTAssertEqual(input.figmaFileId, "android-images-file")
    }

    func testFlutterIconsEntry_figmaFileId_passedToSourceInput() throws {
        let entry = try makeFlutterIconsEntry(figmaFileId: "flutter-icons-file")

        let input = entry.iconsSourceInput()

        XCTAssertEqual(input.figmaFileId, "flutter-icons-file")
    }

    func testFlutterImagesEntry_figmaFileId_passedToSourceInput() throws {
        let entry = try makeFlutterImagesEntry(figmaFileId: "flutter-images-file")

        let input = entry.imagesSourceInput()

        XCTAssertEqual(input.figmaFileId, "flutter-images-file")
    }

    func testFlutterImagesEntry_figmaFileId_passedToSvgSourceInput() throws {
        let entry = try makeFlutterImagesEntry(figmaFileId: "flutter-svg-file")

        let input = entry.svgSourceInput()

        XCTAssertEqual(input.figmaFileId, "flutter-svg-file")
    }

    func testWebIconsEntry_figmaFileId_passedToSourceInput() throws {
        let entry = try makeWebIconsEntry(figmaFileId: "web-icons-file")

        let input = entry.iconsSourceInput()

        XCTAssertEqual(input.figmaFileId, "web-icons-file")
    }

    func testWebImagesEntry_figmaFileId_passedToSourceInput() throws {
        let entry = try makeWebImagesEntry(figmaFileId: "web-images-file")

        let input = entry.imagesSourceInput()

        XCTAssertEqual(input.figmaFileId, "web-images-file")
    }

    // MARK: - Helpers

    private func makeIOSIconsEntry(figmaFileId: String? = nil) throws -> iOSIconsEntry {
        var fields = [String]()
        fields.append("\"format\": \"svg\"")
        fields.append("\"assetsFolder\": \"Icons\"")
        fields.append("\"nameStyle\": \"camelCase\"")
        if let figmaFileId { fields.append("\"figmaFileId\": \"\(figmaFileId)\"") }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(iOSIconsEntry.self, from: Data(json.utf8))
    }

    private func makeIOSImagesEntry(figmaFileId: String? = nil) throws -> iOSImagesEntry {
        var fields = [String]()
        fields.append("\"nameStyle\": \"camelCase\"")
        fields.append("\"assetsFolder\": \"Images\"")
        if let figmaFileId { fields.append("\"figmaFileId\": \"\(figmaFileId)\"") }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(iOSImagesEntry.self, from: Data(json.utf8))
    }

    private func makeAndroidIconsEntry(figmaFileId: String? = nil) throws -> AndroidIconsEntry {
        var fields = [String]()
        fields.append("\"output\": \"drawable\"")
        if let figmaFileId { fields.append("\"figmaFileId\": \"\(figmaFileId)\"") }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(AndroidIconsEntry.self, from: Data(json.utf8))
    }

    private func makeAndroidImagesEntry(figmaFileId: String? = nil) throws -> AndroidImagesEntry {
        var fields = [String]()
        fields.append("\"format\": \"png\"")
        fields.append("\"output\": \"drawable\"")
        if let figmaFileId { fields.append("\"figmaFileId\": \"\(figmaFileId)\"") }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(AndroidImagesEntry.self, from: Data(json.utf8))
    }

    private func makeFlutterIconsEntry(figmaFileId: String? = nil) throws -> FlutterIconsEntry {
        var fields = [String]()
        fields.append("\"output\": \"assets/icons\"")
        if let figmaFileId { fields.append("\"figmaFileId\": \"\(figmaFileId)\"") }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(FlutterIconsEntry.self, from: Data(json.utf8))
    }

    private func makeFlutterImagesEntry(figmaFileId: String? = nil) throws -> FlutterImagesEntry {
        var fields = [String]()
        fields.append("\"output\": \"assets/images\"")
        if let figmaFileId { fields.append("\"figmaFileId\": \"\(figmaFileId)\"") }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(FlutterImagesEntry.self, from: Data(json.utf8))
    }

    private func makeWebIconsEntry(figmaFileId: String? = nil) throws -> WebIconsEntry {
        var fields = [String]()
        fields.append("\"outputDirectory\": \"dist/icons\"")
        if let figmaFileId { fields.append("\"figmaFileId\": \"\(figmaFileId)\"") }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(WebIconsEntry.self, from: Data(json.utf8))
    }

    private func makeWebImagesEntry(figmaFileId: String? = nil) throws -> WebImagesEntry {
        var fields = [String]()
        fields.append("\"outputDirectory\": \"dist/images\"")
        if let figmaFileId { fields.append("\"figmaFileId\": \"\(figmaFileId)\"") }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(WebImagesEntry.self, from: Data(json.utf8))
    }
}

// swiftlint:enable type_name file_length
