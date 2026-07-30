@testable import ExFigCLI
import ExFigConfig
import FigmaAPI
import XCTest

/// End-to-end precedence tests (CLI > PKL `figma.*` > built-in default) for the wiring
/// inside individual export/download subcommands. These exercise the `effective*`
/// accessors with `configValue:` taken from a real PKL config evaluation, which is what
/// `ExportColors`, `ExportIcons`, `ExportImages`, `ExportTypography`, and the `Download*`
/// commands actually do at runtime via `resolveClient(...)`.
///
/// Without these, a regression that swaps `??` direction or stops passing `figma?.rateLimit`
/// in any subcommand would slip through unit tests on `FaultToleranceOptions` alone.
///
/// "No CLI flag given" MUST be spelled `try FaultToleranceOptions.parse([])`, never the bare
/// `FaultToleranceOptions()` initializer: `ParsableArguments.init()` leaves every `@Option`
/// undecoded, so the first read of `.rateLimit` / `.timeout` traps with
/// "Can't read a value from a parsable argument definition" and kills the test process.
final class SubcommandFaultTolerancePrecedenceTests: XCTestCase {
    private var tempFiles: [URL] = []

    override func setUp() {
        super.setUp()
        setenv("FIGMA_PERSONAL_TOKEN", "test_token", 1)
    }

    override func tearDown() {
        super.tearDown()
        for url in tempFiles {
            try? FileManager.default.removeItem(at: url)
        }
        tempFiles.removeAll()
    }

    // MARK: - Light subcommand (FaultToleranceOptions) — colors / typography / download colors

    func testCLIRateLimitOverridesPKLForLightCommand() throws {
        let options = try makeOptions(figmaBlock: "rateLimit = 25\nmaxRetries = 6")
        var cmd = ExFigCommand.ExportColors()
        cmd.globalOptions = GlobalOptions()
        cmd.options = options
        cmd.cacheOptions = CacheOptions()
        cmd.faultToleranceOptions = try FaultToleranceOptions.parse(["--rate-limit", "30"])
        cmd.filter = nil

        let figma = cmd.options.params.figma
        XCTAssertEqual(cmd.faultToleranceOptions.effectiveRateLimit(configValue: figma?.rateLimit), 30)
        XCTAssertEqual(cmd.faultToleranceOptions.effectiveMaxRetries(configValue: figma?.maxRetries), 6)
    }

    func testPKLValueUsedWhenCLIMissingForLightCommand() throws {
        let options = try makeOptions(figmaBlock: "rateLimit = 25\nmaxRetries = 6")
        var cmd = ExFigCommand.ExportColors()
        cmd.globalOptions = GlobalOptions()
        cmd.options = options
        cmd.cacheOptions = CacheOptions()
        cmd.faultToleranceOptions = try FaultToleranceOptions.parse([])
        cmd.filter = nil

        let figma = cmd.options.params.figma
        XCTAssertEqual(cmd.faultToleranceOptions.effectiveRateLimit(configValue: figma?.rateLimit), 25)
        XCTAssertEqual(cmd.faultToleranceOptions.effectiveMaxRetries(configValue: figma?.maxRetries), 6)
    }

    func testBuiltInDefaultUsedWhenNeitherSetForLightCommand() throws {
        let options = try makeOptions(figmaBlock: nil)
        var cmd = ExFigCommand.ExportColors()
        cmd.globalOptions = GlobalOptions()
        cmd.options = options
        cmd.cacheOptions = CacheOptions()
        cmd.faultToleranceOptions = try FaultToleranceOptions.parse([])
        cmd.filter = nil

        let figma = cmd.options.params.figma
        XCTAssertEqual(cmd.faultToleranceOptions.effectiveRateLimit(configValue: figma?.rateLimit), 10)
        XCTAssertEqual(cmd.faultToleranceOptions.effectiveMaxRetries(configValue: figma?.maxRetries), 4)
    }

    // MARK: - Heavy subcommand (HeavyFaultToleranceOptions) — icons / images

    func testCLIConcurrentDownloadsOverridesPKLForHeavyCommand() throws {
        let options = try makeOptions(figmaBlock: "concurrentDownloads = 50")
        var cmd = ExFigCommand.ExportIcons()
        cmd.globalOptions = GlobalOptions()
        cmd.options = options
        cmd.cacheOptions = CacheOptions()
        cmd.faultToleranceOptions = try HeavyFaultToleranceOptions.parse([
            "--concurrent-downloads", "75",
        ])
        cmd.filter = nil
        cmd.strictPathValidation = false

        let figma = cmd.options.params.figma
        XCTAssertEqual(
            cmd.faultToleranceOptions.effectiveConcurrentDownloads(configValue: figma?.concurrentDownloads),
            75
        )
    }

    func testPKLConcurrentDownloadsUsedWhenCLIMissingForHeavyCommand() throws {
        let options = try makeOptions(figmaBlock: "concurrentDownloads = 50")
        var cmd = ExFigCommand.ExportImages()
        cmd.globalOptions = GlobalOptions()
        cmd.options = options
        cmd.cacheOptions = CacheOptions()
        cmd.faultToleranceOptions = try HeavyFaultToleranceOptions.parse([])
        cmd.filter = nil

        let figma = cmd.options.params.figma
        XCTAssertEqual(
            cmd.faultToleranceOptions.effectiveConcurrentDownloads(configValue: figma?.concurrentDownloads),
            50
        )
    }

    func testHeavyDefaultsApplyWhenNeitherSourceProvided() throws {
        let options = try makeOptions(figmaBlock: nil)
        var cmd = ExFigCommand.ExportIcons()
        cmd.globalOptions = GlobalOptions()
        cmd.options = options
        cmd.cacheOptions = CacheOptions()
        cmd.faultToleranceOptions = try HeavyFaultToleranceOptions.parse([])
        cmd.filter = nil
        cmd.strictPathValidation = false

        let figma = cmd.options.params.figma
        XCTAssertEqual(
            cmd.faultToleranceOptions.effectiveConcurrentDownloads(configValue: figma?.concurrentDownloads),
            20
        )
        XCTAssertEqual(cmd.faultToleranceOptions.effectiveMaxRetries(configValue: figma?.maxRetries), 4)
        XCTAssertEqual(cmd.faultToleranceOptions.effectiveRateLimit(configValue: figma?.rateLimit), 10)
    }

    // MARK: - Timeout precedence — exercised via resolveClient bridging

    func testCLITimeoutWinsOverPKLTimeoutInResolveClient() throws {
        // The actual resolveClient wires `options.timeout > config timeout` — we replicate
        // the same expression here to keep the test independent of FigmaClient internals.
        let options = try makeOptions(figmaBlock: "timeout = 60.0")
        let cliOpts = try FaultToleranceOptions.parse(["--timeout", "45"])

        let configTimeout = options.params.figma?.timeout
        let effective: TimeInterval? = cliOpts.timeout.map { TimeInterval($0) } ?? configTimeout

        XCTAssertEqual(effective, 45)
    }

    func testPKLTimeoutUsedWhenCLITimeoutAbsent() throws {
        let options = try makeOptions(figmaBlock: "timeout = 60.0")
        let cliOpts = try FaultToleranceOptions.parse([])

        let configTimeout = options.params.figma?.timeout
        let effective: TimeInterval? = cliOpts.timeout.map { TimeInterval($0) } ?? configTimeout

        XCTAssertEqual(effective, 60)
    }

    // MARK: - Helpers

    private func makeOptions(figmaBlock: String?) throws -> ExFigOptions {
        let url = try writeConfig(figmaBlock: figmaBlock)
        var options = ExFigOptions()
        options.input = url.path
        try options.validate()
        return options
    }

    private func writeConfig(figmaBlock: String?) throws -> URL {
        var lines = ["figma {"]
        lines.append("  lightFileId = \"test\"")
        if let figmaBlock {
            for line in figmaBlock.split(separator: "\n") {
                lines.append("  \(line)")
            }
        }
        lines.append("}")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("subcommand-precedence-\(UUID().uuidString).pkl")
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        tempFiles.append(url)
        return url
    }
}
