# Critical Gotchas

This rule covers Swift 6 concurrency, SwiftLint rules, and other common pitfalls.

## Swift 6 Concurrency

```swift
// Captured vars in task groups must be Sendable
try await withThrowingTaskGroup(of: (Key, Value).self) { [self] group in
    for item in items {
        group.addTask { [item] in  // Capture value, not var
            (item.key, try await self.process(item))
        }
    }
    // ...
}

// Callbacks passed to task groups must be @escaping
func loadImages(
    onBatchProgress: @escaping BatchProgressCallback = { _, _ in }
) async throws -> [ImagePack] {
    // onBatchProgress is captured in task group closures
}
```

### Nested TaskLocal.withValue() Crash (Linux)

**Bug:** https://github.com/swiftlang/swift/issues/75501

Deep nesting of `TaskLocal.withValue()` (10+ levels) causes Swift runtime crash on Linux:
`freed pointer was not the last allocation`

**Symptoms:**
- Works fine on macOS
- Crashes on Linux (Ubuntu 22.04) in batch mode with `--experimental-granular-cache`
- Error appears during task-local allocator cleanup

**Root cause:**
Swift runtime on Linux incorrectly manages task-local allocator when:
1. Deep nesting of `TaskLocal.withValue()` (10+ levels)
2. Nested `withValue` for the **same** TaskLocal inside TaskGroup

**Solution: BatchSharedState actor pattern**

Consolidate all batch state into a single actor with ONE `@TaskLocal`:

```swift
// BAD - 10+ nesting levels crashes on Linux
$collector.withValue(c) {
    $progressView.withValue(p) {
        $context.withValue(ctx) {
            $queue.withValue(q) {
                $configId.withValue(id) {
                    ComponentPreFetcher:
                        $context.withValue(localCtx) { // CRASH!
                        }
                }
            }
        }
    }
}

// GOOD - single nesting level
let state = BatchSharedState(
    context: batchContext,
    progressView: progressView,
    downloadQueue: queue
)
BatchSharedState.$current.withValue(state) {
    // Access via state actor, no nested withValue
}
```

**Key principles:**
1. ONE `@TaskLocal` for all batch shared state
2. Per-config data passed via explicit parameters (`ConfigExecutionContext`)
3. Mutable state lives in actor methods, not nested `withValue`
4. Never create nested `withValue` for the same TaskLocal

### Type-Checker Timeout with Complex Closures

Complex closures inside struct init calls cause "unable to type-check this expression" error.
Break into a separate `let` variable with explicit type annotation:

```swift
// BAD — type-checker timeout
let ctx = ConfigExecutionContext(
    downloadProgressCallback: progressView.map { pv in
        { (assetType, current, total) in await pv.updateProgress(...) }
    }
)

// GOOD — extract closure with explicit types
let callback: ConfigExecutionContext.DownloadProgressCallback? =
    if let pv = progressView {
        { (assetType: ConfigExecutionContext.AssetType, current: Int, total: Int) in
            await pv.updateProgress(...)
        }
    } else { nil }
let ctx = ConfigExecutionContext(downloadProgressCallback: callback)
```

### @Sendable Closures Crash (Linux)

Adding `@Sendable` to closures passed to TaskLocal `withValue` causes runtime crash on Linux:

```swift
// BAD - crashes on Linux
func withContext<T: Sendable>(operation: @Sendable () async -> T) async -> T

// GOOD - works
func withContext<T>(operation: () async -> T) async -> T
```

### #if Inside Array Literals (Swift Limitation)

`#if` does NOT work inside array literals in Swift — not just `Package.swift`, but also
`CommandConfiguration(subcommands: [...])` and any other `[T]` literal context.
Use `var` + `.append()` pattern or computed property returning the array.

## SwiftLint Rules

- Use `Data("string".utf8)` not `"string".data(using: .utf8)!`
- Add `// swiftlint:disable:next force_try` before `try!` in tests
- Add `// swiftlint:disable file_length` for files > 400 lines
- For test files exceeding 400 lines: prefer splitting a second `final class` into its own
  file (e.g. `PKLModuleCacheTests.swift` was extracted from
  `BatchSettingsResolverExtendedTests.swift`) over `// swiftlint:disable file_length`

### swiftlint:disable with Doc Comments

`// swiftlint:disable:next` only suppresses the immediately next line.
With multiline doc comments, use `disable/enable` block BEFORE the doc comment:

```swift
// BAD — orphaned_doc_comment or rule not suppressed
/// Doc comment...
// swiftlint:disable:next function_parameter_count
func foo(a:, b:, c:, d:, e:, f:) {}

// GOOD
// swiftlint:disable function_parameter_count

/// Doc comment...
func foo(a:, b:, c:, d:, e:, f:) {}

// swiftlint:enable function_parameter_count
```

### multiple_closures_with_trailing_closure

When a function accepts 2+ closure parameters, trailing closure syntax triggers this rule.
Use explicit argument labels for all closures:

```swift
// BAD — trailing closure with multiple closures
withExportReport(buildStats: { ... }) {
    try await export()
}

// GOOD — explicit label
withExportReport(
    buildStats: { ... },
    export: { try await export() }
)
```

### void_function_in_ternary False Positive

SwiftLint flags `NooraUI.format()` calls in ternary operators as `void_function_in_ternary` even though they return `String`.
Fix by extracting into separate `let` variables:

```swift
// BAD - triggers SwiftLint
let icon: String = if useColors {
    success ? NooraUI.format(.success("✓")) : NooraUI.format(.danger("✗"))
} else { ... }

// GOOD
let successIcon = useColors ? NooraUI.format(.success("✓")) : "✓"
let failIcon = useColors ? NooraUI.format(.danger("✗")) : "✗"
let icon = success ? successIcon : failIcon
```

### Actor vs Lock for Sync-Only State

When all operations are synchronous (array append, file read), use `Lock<T>` (NSLock wrapper)
instead of `actor`. Actor requires `await` which forces `DispatchSemaphore` bridges from sync
contexts — creating deadlock risk. See `WarningCollector`, `ManifestTracker` for the pattern.

```swift
// BAD — actor with sync-only ops forces semaphore bridge from sync callers
actor Collector {
    private var items: [String] = []
    func add(_ item: String) { items.append(item) }
}

// GOOD — Lock is sync, no await needed
final class Collector: Sendable {
    private let storage = Lock<[String]>([])
    func add(_ item: String) { storage.withLock { $0.append(item) } }
}
```

## ParsableArguments: never construct with bare `init()` and then read it

`ParsableArguments.init()` satisfies the protocol but leaves every `@Option`/`@Flag` **undecoded**.
Assigning is fine; the first *read* traps and kills the whole test process:

```
Can't read a value from a parsable argument definition.
```

Under `swift test --parallel` this shows up as a suite that logs `started` with no `passed` and a
non-zero exit — no `XCTAssert` failure line, so it is easy to mistake for a green run.

```swift
// BAD — traps on the first read of .rateLimit
cmd.faultToleranceOptions = FaultToleranceOptions()
_ = cmd.faultToleranceOptions.effectiveRateLimit(configValue: nil)

// GOOD — "no CLI flag given", all defaults decoded
cmd.faultToleranceOptions = try FaultToleranceOptions.parse([])
```

Applies to `filter`, `strictPathValidation`, and every `@OptionGroup` on manually built subcommands
(the `BatchConfigRunner.make*` pattern). Production is safe — `BatchConfigRunner` receives
already-parsed option groups; only hand-rolled test instances hit this.

## Test Helpers for Codable Types

```swift
extension SomeType {
    static func make(param: String) -> SomeType {
        let json = "{\"param\": \"\(param)\"}"
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(SomeType.self, from: Data(json.utf8))
    }
}
```

## PklSwift Error Messages

`PklSwift.PklError` has a `message` field but doesn't conform to `LocalizedError`.
Without the extension in `PKLEvaluator.swift`, `.localizedDescription` returns useless
`"The operation couldn't be completed. (PklSwift.PklError error 1.)"` instead of the actual PKL error.
Fix: `extension PklError: @retroactive LocalizedError` in `Sources/ExFigConfig/PKL/PKLEvaluator.swift`.

## PKL Test Fixtures

### Number-typed fields require `.0` suffix

pkl-swift strictly distinguishes `Int` vs `Double` at decode time. PKL fields generated as
`Double?` (e.g. `figma.timeout: Number(isBetween(1, 600))? = 30.0`) must be written with
explicit decimal in test fixtures — otherwise decode throws
`DecodingError.typeMismatch: expected value of type Double`:

```pkl
# BAD — pkl-swift fails to decode
figma { timeout = 60 }

# GOOD
figma { timeout = 60.0 }
```

This is independent of how PKL itself parses the value; the breakage is in pkl-swift's
strict type matching, not in PKL semantics.

### PKL constraints validate at amends-time, not at sanitize-time

`Int(isBetween(1, 50))` constraints in `Schemas/*.pkl` fail during PKL evaluation, BEFORE
`FaultToleranceValidator.sanitized*` ever runs. Fixtures with `parallel = 99` will fail
to load entirely, not produce a clamped value:

```swift
// BAD — fixture never loads, test asserts wrong condition
let url = try BatchResolverFixture.make(batch: "parallel = 99")

// GOOD — to test sanitizer with out-of-range values, call it directly
XCTAssertEqual(FaultToleranceValidator.sanitizedParallel(99, ui: ui), 3)
```

If a test needs both an in-range PKL value AND an out-of-range case, split into two tests.

## Figma API Rate Limits

**Official docs:** https://developers.figma.com/docs/rest-api/rate-limits/

- Use `maxConcurrentBatches = 3` for parallel requests
- Tier 1 endpoints (files, images): 10-20 req/min depending on plan (Starter->Enterprise)
- Tier 2 endpoints: 25-100 req/min
- Tier 3 endpoints: 50-150 req/min
- On 429 error: respect `Retry-After` header
