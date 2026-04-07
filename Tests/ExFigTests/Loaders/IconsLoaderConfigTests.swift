// swiftlint:disable file_length type_body_length

import ExFig_Android
import ExFig_Flutter
import ExFig_iOS
import ExFig_Web
@testable import ExFigCLI
import ExFigCore
import XCTest

final class IconsLoaderConfigTests: XCTestCase {
    // MARK: - iOS Frame Name Resolution

    func testForIOS_entryFrameNameOverridesCommon() throws {
        let entry = try makeIOSEntry(figmaFrameName: "Actions")
        let params = PKLConfig.make(lightFileId: "test", iconsFrameName: "CommonIcons")

        let config = IconsLoaderConfig.forIOS(entry: entry, params: params)

        XCTAssertEqual(config.frameName, "Actions")
    }

    func testForIOS_fallbackToCommonFrameName() throws {
        let entry = try makeIOSEntry(figmaFrameName: nil)
        let params = PKLConfig.make(lightFileId: "test", iconsFrameName: "CommonIcons")

        let config = IconsLoaderConfig.forIOS(entry: entry, params: params)

        XCTAssertEqual(config.frameName, "CommonIcons")
    }

    func testForIOS_fallbackToDefaultFrameName() throws {
        let entry = try makeIOSEntry(figmaFrameName: nil)
        let params = PKLConfig.make(lightFileId: "test")

        let config = IconsLoaderConfig.forIOS(entry: entry, params: params)

        XCTAssertEqual(config.frameName, "Icons")
    }

    func testForIOS_passesFormatField() throws {
        let entry = try makeIOSEntry(format: "svg")
        let params = PKLConfig.make(lightFileId: "test")

        let config = IconsLoaderConfig.forIOS(entry: entry, params: params)

        XCTAssertEqual(config.format, .svg)
    }

    func testForIOS_passesPDFFormat() throws {
        let entry = try makeIOSEntry(format: "pdf")
        let params = PKLConfig.make(lightFileId: "test")

        let config = IconsLoaderConfig.forIOS(entry: entry, params: params)

        XCTAssertEqual(config.format, .pdf)
    }

    func testForIOS_passesRenderModeFields() throws {
        let entry = try makeIOSEntry(
            renderMode: "original",
            renderModeDefaultSuffix: "_default",
            renderModeOriginalSuffix: "_original",
            renderModeTemplateSuffix: "_template"
        )
        let params = PKLConfig.make(lightFileId: "test")

        let config = IconsLoaderConfig.forIOS(entry: entry, params: params)

        XCTAssertEqual(config.renderMode, .original)
        XCTAssertEqual(config.renderModeDefaultSuffix, "_default")
        XCTAssertEqual(config.renderModeOriginalSuffix, "_original")
        XCTAssertEqual(config.renderModeTemplateSuffix, "_template")
    }

    func testForIOS_nilRenderModeFieldsWhenNotProvided() throws {
        let entry = try makeIOSEntry()
        let params = PKLConfig.make(lightFileId: "test")

        let config = IconsLoaderConfig.forIOS(entry: entry, params: params)

        XCTAssertNil(config.renderMode)
        XCTAssertNil(config.renderModeDefaultSuffix)
        XCTAssertNil(config.renderModeOriginalSuffix)
        XCTAssertNil(config.renderModeTemplateSuffix)
    }

    // MARK: - Android Frame Name Resolution

    func testForAndroid_entryFrameNameOverridesCommon() throws {
        let entry = try makeAndroidEntry(figmaFrameName: "Actions")
        let params = PKLConfig.make(lightFileId: "test", iconsFrameName: "CommonIcons")

        let config = IconsLoaderConfig.forAndroid(entry: entry, params: params)

        XCTAssertEqual(config.frameName, "Actions")
    }

    func testForAndroid_fallbackToCommonFrameName() throws {
        let entry = try makeAndroidEntry(figmaFrameName: nil)
        let params = PKLConfig.make(lightFileId: "test", iconsFrameName: "CommonIcons")

        let config = IconsLoaderConfig.forAndroid(entry: entry, params: params)

        XCTAssertEqual(config.frameName, "CommonIcons")
    }

    func testForAndroid_fallbackToDefault() throws {
        let entry = try makeAndroidEntry(figmaFrameName: nil)
        let params = PKLConfig.make(lightFileId: "test")

        let config = IconsLoaderConfig.forAndroid(entry: entry, params: params)

        XCTAssertEqual(config.frameName, "Icons")
    }

    func testForAndroid_hasNoIOSSpecificFields() throws {
        let entry = try makeAndroidEntry()
        let params = PKLConfig.make(lightFileId: "test")

        let config = IconsLoaderConfig.forAndroid(entry: entry, params: params)

        XCTAssertNil(config.format)
        XCTAssertNil(config.renderMode)
        XCTAssertNil(config.renderModeDefaultSuffix)
        XCTAssertNil(config.renderModeOriginalSuffix)
        XCTAssertNil(config.renderModeTemplateSuffix)
    }

    // MARK: - Flutter Frame Name Resolution

    func testForFlutter_entryFrameNameOverridesCommon() throws {
        let entry = try makeFlutterEntry(figmaFrameName: "Actions")
        let params = PKLConfig.make(lightFileId: "test", iconsFrameName: "CommonIcons")

        let config = IconsLoaderConfig.forFlutter(entry: entry, params: params)

        XCTAssertEqual(config.frameName, "Actions")
    }

    func testForFlutter_fallbackToCommonFrameName() throws {
        let entry = try makeFlutterEntry(figmaFrameName: nil)
        let params = PKLConfig.make(lightFileId: "test", iconsFrameName: "CommonIcons")

        let config = IconsLoaderConfig.forFlutter(entry: entry, params: params)

        XCTAssertEqual(config.frameName, "CommonIcons")
    }

    func testForFlutter_fallbackToDefault() throws {
        let entry = try makeFlutterEntry(figmaFrameName: nil)
        let params = PKLConfig.make(lightFileId: "test")

        let config = IconsLoaderConfig.forFlutter(entry: entry, params: params)

        XCTAssertEqual(config.frameName, "Icons")
    }

    func testForFlutter_hasNoIOSSpecificFields() throws {
        let entry = try makeFlutterEntry()
        let params = PKLConfig.make(lightFileId: "test")

        let config = IconsLoaderConfig.forFlutter(entry: entry, params: params)

        XCTAssertNil(config.format)
        XCTAssertNil(config.renderMode)
        XCTAssertNil(config.renderModeDefaultSuffix)
        XCTAssertNil(config.renderModeOriginalSuffix)
        XCTAssertNil(config.renderModeTemplateSuffix)
    }

    // MARK: - Default Config

    func testDefaultConfig_usesCommonFrameName() {
        let params = PKLConfig.make(lightFileId: "test", iconsFrameName: "CommonIcons")

        let config = IconsLoaderConfig.defaultConfig(params: params)

        XCTAssertEqual(config.frameName, "CommonIcons")
    }

    func testDefaultConfig_fallbackToDefault() {
        let params = PKLConfig.make(lightFileId: "test")

        let config = IconsLoaderConfig.defaultConfig(params: params)

        XCTAssertEqual(config.frameName, "Icons")
    }

    func testDefaultConfig_hasNoIOSSpecificFields() {
        let params = PKLConfig.make(lightFileId: "test")

        let config = IconsLoaderConfig.defaultConfig(params: params)

        XCTAssertNil(config.format)
        XCTAssertNil(config.renderMode)
        XCTAssertNil(config.renderModeDefaultSuffix)
        XCTAssertNil(config.renderModeOriginalSuffix)
        XCTAssertNil(config.renderModeTemplateSuffix)
    }

    func testDefaultConfig_hasDefaultRTLProperty() {
        let params = PKLConfig.make(lightFileId: "test")

        let config = IconsLoaderConfig.defaultConfig(params: params)

        XCTAssertEqual(config.rtlProperty, "RTL")
    }

    // MARK: - Regression: SVG format must not be mapped to nil

    /// Regression test: when IconsLoaderConfig is constructed with .svg format,
    /// it must remain .svg (not nil). A previous bug used `source.format == .pdf ? .pdf : nil`
    /// which turned .svg into nil, causing iOS to always export PDF instead of SVG.
    func testSVGFormatPreservedInDirectConstruction() {
        let config = IconsLoaderConfig(
            entryFileId: nil,
            frameName: "Icons",
            pageName: nil,
            format: .svg,
            renderMode: nil,
            renderModeDefaultSuffix: nil,
            renderModeOriginalSuffix: nil,
            renderModeTemplateSuffix: nil,
            rtlProperty: nil,
            rtlActiveValues: nil
        )

        XCTAssertEqual(config.format, .svg)
    }

    func testPDFFormatPreservedInDirectConstruction() {
        let config = IconsLoaderConfig(
            entryFileId: nil,
            frameName: "Icons",
            pageName: nil,
            format: .pdf,
            renderMode: nil,
            renderModeDefaultSuffix: nil,
            renderModeOriginalSuffix: nil,
            renderModeTemplateSuffix: nil,
            rtlProperty: nil,
            rtlActiveValues: nil
        )

        XCTAssertEqual(config.format, .pdf)
    }

    /// Regression test: verifies the full data path from iOSIconsEntry with SVG format
    /// through IconsSourceInput to IconsLoaderConfig — format must be preserved at each step.
    func testSVGFormatPreservedThroughEntryToSourceToConfig() throws {
        let entry = try makeIOSEntry(format: "svg")

        // Step 1: entry → IconsSourceInput
        let source = entry.iconsSourceInput()
        XCTAssertEqual(source.format, .svg, "SVG format must survive entry → source conversion")

        // Step 2: source → IconsLoaderConfig (simulates IconsExportContextImpl.loadIcons)
        let config = IconsLoaderConfig(
            entryFileId: source.figmaFileId,
            frameName: source.frameName,
            pageName: source.pageName,
            format: source.format,
            renderMode: source.renderMode,
            renderModeDefaultSuffix: source.renderModeDefaultSuffix,
            renderModeOriginalSuffix: source.renderModeOriginalSuffix,
            renderModeTemplateSuffix: source.renderModeTemplateSuffix,
            rtlProperty: source.rtlProperty,
            rtlActiveValues: source.rtlActiveValues
        )
        XCTAssertEqual(config.format, .svg, "SVG format must survive source → config conversion")
    }

    func testPDFFormatPreservedThroughEntryToSourceToConfig() throws {
        let entry = try makeIOSEntry(format: "pdf")

        let source = entry.iconsSourceInput()
        XCTAssertEqual(source.format, .pdf)

        let config = IconsLoaderConfig(
            entryFileId: source.figmaFileId,
            frameName: source.frameName,
            pageName: source.pageName,
            format: source.format,
            renderMode: source.renderMode,
            renderModeDefaultSuffix: source.renderModeDefaultSuffix,
            renderModeOriginalSuffix: source.renderModeOriginalSuffix,
            renderModeTemplateSuffix: source.renderModeTemplateSuffix,
            rtlProperty: source.rtlProperty,
            rtlActiveValues: source.rtlActiveValues
        )
        XCTAssertEqual(config.format, .pdf)
    }

    // MARK: - RTL Property Passthrough

    func testRTLPropertyPreservedThroughEntryToSourceToConfig() throws {
        let entry = try makeIOSEntry(rtlProperty: "RTL")

        // Step 1: entry → IconsSourceInput
        let source = entry.iconsSourceInput()
        XCTAssertEqual(source.rtlProperty, "RTL", "rtlProperty must survive entry → source conversion")

        // Step 2: source → IconsLoaderConfig
        let config = IconsLoaderConfig(
            entryFileId: source.figmaFileId,
            frameName: source.frameName,
            pageName: source.pageName,
            format: source.format,
            renderMode: source.renderMode,
            renderModeDefaultSuffix: source.renderModeDefaultSuffix,
            renderModeOriginalSuffix: source.renderModeOriginalSuffix,
            renderModeTemplateSuffix: source.renderModeTemplateSuffix,
            rtlProperty: source.rtlProperty,
            rtlActiveValues: source.rtlActiveValues
        )
        XCTAssertEqual(config.rtlProperty, "RTL", "rtlProperty must survive source → config conversion")
    }

    func testRTLPropertyNilPreservedThroughEntryToSource() throws {
        let entry = try makeIOSEntry(rtlProperty: nil)

        let source = entry.iconsSourceInput()
        XCTAssertNil(source.rtlProperty, "nil rtlProperty must be preserved through entry → source")
    }

    func testRTLPropertyCustomNamePreservedThroughEntryToSource() throws {
        let entry = try makeIOSEntry(rtlProperty: "IsRTL")

        let source = entry.iconsSourceInput()
        XCTAssertEqual(source.rtlProperty, "IsRTL", "Custom rtlProperty name must be preserved")
    }

    // MARK: - Page Name Resolution

    func testForIOS_entryPageNameOverridesCommon() throws {
        let entry = try makeIOSEntry(figmaPageName: "Outlined")
        let params = PKLConfig.make(lightFileId: "test", iconsPageName: "Filled")

        let config = IconsLoaderConfig.forIOS(entry: entry, params: params)

        XCTAssertEqual(config.pageName, "Outlined")
    }

    func testForIOS_fallbackToCommonPageName() throws {
        let entry = try makeIOSEntry()
        let params = PKLConfig.make(lightFileId: "test", iconsPageName: "Filled")

        let config = IconsLoaderConfig.forIOS(entry: entry, params: params)

        XCTAssertEqual(config.pageName, "Filled")
    }

    func testForIOS_pageNameNilByDefault() throws {
        let entry = try makeIOSEntry()
        let params = PKLConfig.make(lightFileId: "test")

        let config = IconsLoaderConfig.forIOS(entry: entry, params: params)

        XCTAssertNil(config.pageName)
    }

    func testForAndroid_entryPageNameOverridesCommon() throws {
        let entry = try makeAndroidEntry(figmaPageName: "Outlined")
        let params = PKLConfig.make(lightFileId: "test", iconsPageName: "Filled")

        let config = IconsLoaderConfig.forAndroid(entry: entry, params: params)

        XCTAssertEqual(config.pageName, "Outlined")
    }

    func testDefaultConfig_usesCommonPageName() {
        let params = PKLConfig.make(lightFileId: "test", iconsPageName: "Filled")

        let config = IconsLoaderConfig.defaultConfig(params: params)

        XCTAssertEqual(config.pageName, "Filled")
    }

    func testDefaultConfig_pageNameNilByDefault() {
        let params = PKLConfig.make(lightFileId: "test")

        let config = IconsLoaderConfig.defaultConfig(params: params)

        XCTAssertNil(config.pageName)
    }

    func testPageNamePreservedThroughEntryToSourceToConfig() throws {
        let entry = try makeIOSEntry(figmaPageName: "Outlined")

        let source = entry.iconsSourceInput()
        XCTAssertEqual(source.pageName, "Outlined", "pageName must survive entry → source conversion")

        let config = IconsLoaderConfig(
            entryFileId: source.figmaFileId,
            frameName: source.frameName,
            pageName: source.pageName,
            format: source.format,
            renderMode: source.renderMode,
            renderModeDefaultSuffix: source.renderModeDefaultSuffix,
            renderModeOriginalSuffix: source.renderModeOriginalSuffix,
            renderModeTemplateSuffix: source.renderModeTemplateSuffix,
            rtlProperty: source.rtlProperty,
            rtlActiveValues: source.rtlActiveValues
        )
        XCTAssertEqual(config.pageName, "Outlined", "pageName must survive source → config conversion")
    }

    func testForFlutter_entryPageNameOverridesCommon() throws {
        let entry = try makeFlutterEntry(figmaPageName: "Outlined")
        let params = PKLConfig.make(lightFileId: "test", iconsPageName: "Filled")

        let config = IconsLoaderConfig.forFlutter(entry: entry, params: params)

        XCTAssertEqual(config.pageName, "Outlined")
    }

    func testForWeb_entryPageNameOverridesCommon() throws {
        let entry = try makeWebEntry(figmaPageName: "Outlined")
        let params = PKLConfig.make(lightFileId: "test", iconsPageName: "Filled")

        let config = IconsLoaderConfig.forWeb(entry: entry, params: params)

        XCTAssertEqual(config.pageName, "Outlined")
    }

    // MARK: - Helpers

    private func makeIOSEntry(
        figmaFrameName: String? = nil,
        figmaPageName: String? = nil,
        format: String = "svg",
        assetsFolder: String = "Icons",
        nameStyle: String = "camelCase",
        renderMode: String? = nil,
        renderModeDefaultSuffix: String? = nil,
        renderModeOriginalSuffix: String? = nil,
        renderModeTemplateSuffix: String? = nil,
        rtlProperty: String? = nil
    ) throws -> iOSIconsEntry {
        var json = """
        {
            "format": "\(format)",
            "assetsFolder": "\(assetsFolder)",
            "nameStyle": "\(nameStyle)"
        """

        if let figmaFrameName {
            json = json.replacingOccurrences(of: "{", with: "{ \"figmaFrameName\": \"\(figmaFrameName)\",")
        }
        if let figmaPageName {
            json += ", \"figmaPageName\": \"\(figmaPageName)\""
        }
        if let renderMode {
            json += ", \"renderMode\": \"\(renderMode)\""
        }
        if let renderModeDefaultSuffix {
            json += ", \"renderModeDefaultSuffix\": \"\(renderModeDefaultSuffix)\""
        }
        if let renderModeOriginalSuffix {
            json += ", \"renderModeOriginalSuffix\": \"\(renderModeOriginalSuffix)\""
        }
        if let renderModeTemplateSuffix {
            json += ", \"renderModeTemplateSuffix\": \"\(renderModeTemplateSuffix)\""
        }
        if let rtlProperty {
            json += ", \"rtlProperty\": \"\(rtlProperty)\""
        }
        json += "}"

        return try JSONDecoder().decode(iOSIconsEntry.self, from: Data(json.utf8))
    }

    private func makeAndroidEntry(
        figmaFrameName: String? = nil,
        figmaPageName: String? = nil,
        output: String = "drawable"
    ) throws -> AndroidIconsEntry {
        var json = """
        {
            "output": "\(output)"
        """

        if let figmaFrameName {
            json = json.replacingOccurrences(of: "{", with: "{ \"figmaFrameName\": \"\(figmaFrameName)\",")
        }
        if let figmaPageName {
            json += ", \"figmaPageName\": \"\(figmaPageName)\""
        }
        json += "}"

        return try JSONDecoder().decode(AndroidIconsEntry.self, from: Data(json.utf8))
    }

    private func makeFlutterEntry(
        figmaFrameName: String? = nil,
        figmaPageName: String? = nil,
        output: String = "assets/icons"
    ) throws -> FlutterIconsEntry {
        var json = """
        {
            "output": "\(output)"
        """

        if let figmaFrameName {
            json = json.replacingOccurrences(of: "{", with: "{ \"figmaFrameName\": \"\(figmaFrameName)\",")
        }
        if let figmaPageName {
            json += ", \"figmaPageName\": \"\(figmaPageName)\""
        }
        json += "}"

        return try JSONDecoder().decode(FlutterIconsEntry.self, from: Data(json.utf8))
    }

    private func makeWebEntry(
        figmaFrameName: String? = nil,
        figmaPageName: String? = nil,
        outputDirectory: String = "assets/icons"
    ) throws -> WebIconsEntry {
        var json = """
        {
            "outputDirectory": "\(outputDirectory)"
        """

        if let figmaFrameName {
            json = json.replacingOccurrences(of: "{", with: "{ \"figmaFrameName\": \"\(figmaFrameName)\",")
        }
        if let figmaPageName {
            json += ", \"figmaPageName\": \"\(figmaPageName)\""
        }
        json += "}"

        return try JSONDecoder().decode(WebIconsEntry.self, from: Data(json.utf8))
    }
}
