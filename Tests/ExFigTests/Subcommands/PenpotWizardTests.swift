@testable import ExFigCLI
import ExFigCore
import Testing

// MARK: - extractPenpotFileId Tests

struct ExtractPenpotFileIdTests {
    @Test("Extracts UUID from full workspace URL")
    func fullWorkspaceURL() {
        let url = "https://design.penpot.app/#/workspace/team-123?file-id=abc-def-123&page-id=page-456"
        #expect(extractPenpotFileId(from: url) == "abc-def-123")
    }

    @Test("Extracts UUID when file-id is last query param")
    func fileIdAtEnd() {
        let url = "https://design.penpot.app/#/workspace/team?page-id=p1&file-id=a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        #expect(extractPenpotFileId(from: url) == "a1b2c3d4-e5f6-7890-abcd-ef1234567890")
    }

    @Test("Returns bare UUID as-is")
    func bareUUID() {
        let uuid = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        #expect(extractPenpotFileId(from: uuid) == uuid)
    }

    @Test("Returns input as-is when no file-id param")
    func noFileIdParam() {
        let url = "https://design.penpot.app/#/workspace/team-123?page-id=page-456"
        #expect(extractPenpotFileId(from: url) == url)
    }

    @Test("Trims whitespace")
    func trimWhitespace() {
        let input = "  abc-def-123  "
        #expect(extractPenpotFileId(from: input) == "abc-def-123")
    }

    @Test("Self-hosted URL with valid UUID")
    func selfHostedURL() {
        let url = "https://penpot.mycompany.com/#/workspace/team?file-id=a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        #expect(extractPenpotFileId(from: url) == "a1b2c3d4-e5f6-7890-abcd-ef1234567890")
    }
}

// MARK: - applyPenpotResult Tests

struct ApplyPenpotResultTests {
    @Test("Removes Figma import and config section")
    func removesFigmaSection() {
        let result = makePenpotResult()
        let output = InitWizard.applyPenpotResult(result, to: iosConfigFileContents)
        #expect(!output.contains("import \".exfig/schemas/Figma.pkl\""))
        #expect(!output.contains("figma = new Figma.FigmaConfig {"))
    }

    @Test("Inserts penpotSource block into platform entries")
    func insertsPenpotSource() {
        let result = makePenpotResult()
        let output = InitWizard.applyPenpotResult(result, to: iosConfigFileContents)
        #expect(output.contains("penpotSource = new Common.PenpotSource {"))
        #expect(output.contains("fileId = \"PENPOT_FILE_UUID\""))
    }

    @Test("Includes custom base URL when provided")
    func customBaseURL() {
        let result = makePenpotResult(penpotBaseURL: "https://penpot.mycompany.com/")
        let output = InitWizard.applyPenpotResult(result, to: iosConfigFileContents)
        #expect(output.contains("baseUrl = \"https://penpot.mycompany.com/\""))
    }

    @Test("Omits base URL line when nil")
    func noBaseURL() {
        let result = makePenpotResult(penpotBaseURL: nil)
        let output = InitWizard.applyPenpotResult(result, to: iosConfigFileContents)
        #expect(!output.contains("baseUrl"))
    }

    @Test("Removes unselected asset types")
    func removesUnselected() {
        let result = makePenpotResult(selectedAssetTypes: [.colors])
        let output = InitWizard.applyPenpotResult(result, to: iosConfigFileContents)
        #expect(!output.contains("icons = new"))
        #expect(!output.contains("images = new"))
        #expect(!output.contains("typography = new"))
    }

    @Test("Removes common colors/icons/images/typography sections")
    func removesCommonSections() {
        let result = makePenpotResult()
        let output = InitWizard.applyPenpotResult(result, to: iosConfigFileContents)
        #expect(!output.contains("colors = new Common.Colors {"))
        #expect(!output.contains("icons = new Common.Icons {"))
        #expect(!output.contains("images = new Common.Images {"))
        #expect(!output.contains("typography = new Common.Typography {"))
    }

    @Test("Output has balanced braces")
    func balancedBraces() {
        let result = makePenpotResult()
        let output = InitWizard.applyPenpotResult(result, to: iosConfigFileContents)
        let openCount = output.filter { $0 == "{" }.count
        let closeCount = output.filter { $0 == "}" }.count
        #expect(openCount == closeCount, "Unbalanced braces: \(openCount) open vs \(closeCount) close")
    }

    @Test("Includes penpotSource in icons platform entry")
    func iconsPlatformEntryHasPenpotSource() {
        let result = makePenpotResult(iconsFrameName: "Icons/Navigation")
        let output = InitWizard.applyPenpotResult(result, to: iosConfigFileContents)
        // penpotSource block should be inserted into the icons platform entry
        #expect(output.contains("penpotSource = new Common.PenpotSource {"))
        #expect(output.contains("fileId = \"PENPOT_FILE_UUID\""))
    }

    @Test("Includes penpotSource in images platform entry")
    func imagesPlatformEntryHasPenpotSource() {
        let result = makePenpotResult(imagesFrameName: "Images/Hero")
        let output = InitWizard.applyPenpotResult(result, to: iosConfigFileContents)
        #expect(output.contains("penpotSource = new Common.PenpotSource {"))
    }

    @Test("Works with Android template")
    func androidTemplate() {
        let result = makePenpotResult(platform: .android)
        let output = InitWizard.applyPenpotResult(result, to: androidConfigFileContents)
        #expect(output.contains("penpotSource = new Common.PenpotSource {"))
        #expect(!output.contains("figma = new Figma.FigmaConfig {"))
        let openCount = output.filter { $0 == "{" }.count
        let closeCount = output.filter { $0 == "}" }.count
        #expect(openCount == closeCount, "Unbalanced braces: \(openCount) vs \(closeCount)")
    }

    @Test("Works with Flutter template")
    func flutterTemplate() {
        let result = makePenpotResult(
            platform: .flutter,
            selectedAssetTypes: [.colors, .icons, .images]
        )
        let output = InitWizard.applyPenpotResult(result, to: flutterConfigFileContents)
        #expect(output.contains("penpotSource = new Common.PenpotSource {"))
        let openCount = output.filter { $0 == "{" }.count
        let closeCount = output.filter { $0 == "}" }.count
        #expect(openCount == closeCount, "Unbalanced braces: \(openCount) vs \(closeCount)")
    }

    @Test("Works with Web template")
    func webTemplate() {
        let result = makePenpotResult(
            platform: .web,
            selectedAssetTypes: [.colors, .icons, .images]
        )
        let output = InitWizard.applyPenpotResult(result, to: webConfigFileContents)
        #expect(output.contains("penpotSource = new Common.PenpotSource {"))
        let openCount = output.filter { $0 == "{" }.count
        let closeCount = output.filter { $0 == "}" }.count
        #expect(openCount == closeCount, "Unbalanced braces: \(openCount) vs \(closeCount)")
    }

    // MARK: - Helpers

    private func makePenpotResult(
        platform: Platform = .ios,
        selectedAssetTypes: [InitAssetType] = [.colors, .icons, .images, .typography],
        lightFileId: String = "PENPOT_FILE_UUID",
        iconsFrameName: String? = nil,
        imagesFrameName: String? = nil,
        penpotBaseURL: String? = nil
    ) -> InitWizardResult {
        InitWizardResult(
            designSource: .penpot,
            platform: platform,
            selectedAssetTypes: selectedAssetTypes,
            lightFileId: lightFileId,
            darkFileId: nil,
            iconsFrameName: iconsFrameName,
            iconsPageName: nil,
            imagesFrameName: imagesFrameName,
            imagesPageName: nil,
            variablesConfig: nil,
            penpotBaseURL: penpotBaseURL
        )
    }
}
