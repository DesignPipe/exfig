import ExFigCore
import Foundation
import Testing

struct ParallelMapEntriesTests {
    @Test("Empty input returns empty array")
    func emptyInput() async throws {
        let results: [Int] = try await parallelMapEntries([Int]()) { $0 * 2 }
        #expect(results.isEmpty)
    }

    @Test("Single entry returns correct result")
    func singleEntry() async throws {
        let results = try await parallelMapEntries([42]) { $0 * 2 }
        #expect(results == [84])
    }

    @Test("Multiple entries produce correct results")
    func multipleEntries() async throws {
        let input = [1, 2, 3, 4, 5]
        let results = try await parallelMapEntries(input) { $0 * 10 }
        #expect(results == [10, 20, 30, 40, 50])
    }

    @Test("Results preserve input order")
    func preservesOrder() async throws {
        let input = Array(0 ..< 20)
        let results = try await parallelMapEntries(input, maxParallel: 3) { value in
            // Add small random delay to encourage out-of-order completion
            try await Task.sleep(for: .milliseconds(Int.random(in: 1 ... 10)))
            return value
        }
        #expect(results == input)
    }

    @Test("maxParallel=1 processes sequentially")
    func sequentialFallback() async throws {
        let input = [1, 2, 3, 4, 5]
        // With maxParallel=1, results should be in order and correct
        let results = try await parallelMapEntries(input, maxParallel: 1) { value in
            value * 2
        }

        #expect(results == [2, 4, 6, 8, 10])
    }

    @Test("Error propagation cancels remaining tasks")
    func errorPropagation() async throws {
        struct TestError: Error {}

        await #expect(throws: TestError.self) {
            try await parallelMapEntries([1, 2, 3, 4, 5], maxParallel: 2) { value in
                if value == 3 { throw TestError() }
                return value
            }
        }
    }

    @Test("Parallel verification — concurrent execution observed")
    func parallelVerification() async throws {
        let counter = ConcurrencyCounter()
        let input = Array(0 ..< 10)

        let results = try await parallelMapEntries(input, maxParallel: 3) { value in
            counter.enter()
            try await Task.sleep(for: .milliseconds(50))
            counter.exit()
            return value
        }

        #expect(results == Array(0 ..< 10))
        #expect(counter.peak > 1, "Expected concurrent execution, peak was \(counter.peak)")
        #expect(counter.peak <= 3, "Peak concurrency \(counter.peak) exceeded maxParallel 3")
    }

    @Test("Aggregation pattern — sum of results")
    func aggregation() async throws {
        let input = [10, 20, 30]
        let counts = try await parallelMapEntries(input) { $0 }
        let total = counts.reduce(0, +)
        #expect(total == 60)
    }

    @Test("maxParallel=0 is clamped to 1")
    func maxParallelZero() async throws {
        let results = try await parallelMapEntries([1, 2, 3], maxParallel: 0) { $0 * 2 }
        #expect(results == [2, 4, 6])
    }

    @Test("Negative maxParallel is clamped to 1")
    func maxParallelNegative() async throws {
        let results = try await parallelMapEntries([1, 2, 3], maxParallel: -1) { $0 * 2 }
        #expect(results == [2, 4, 6])
    }

    @Test("maxParallel greater than entry count works correctly")
    func maxParallelExceedsCount() async throws {
        let results = try await parallelMapEntries([1, 2, 3], maxParallel: 100) { $0 * 2 }
        #expect(results == [2, 4, 6])
    }
}

// MARK: - Helpers

private final class ConcurrencyCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _active = 0
    private var _peak = 0

    func enter() {
        lock.lock()
        _active += 1
        _peak = max(_peak, _active)
        lock.unlock()
    }

    func exit() {
        lock.lock()
        _active -= 1
        lock.unlock()
    }

    var peak: Int {
        lock.lock()
        defer { lock.unlock() }
        return _peak
    }
}
