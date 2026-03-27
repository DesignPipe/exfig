import FigmaAPI
import Foundation

/// Deduplicating cache for Figma Components API responses.
///
/// Concurrent callers requesting the same `fileId` share a single in-flight `Task`.
/// First caller triggers the fetch; subsequent callers await the same result.
/// Failed tasks are evicted so subsequent callers can retry.
///
/// Same pattern as ``VariablesCache``. Used in standalone (non-batch) mode
/// when multiple icon/image entries share the same Figma file.
final class ComponentsCache: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [String: Task<[Component], Error>] = [:]

    func get(
        fileId: String,
        fetch: @escaping @Sendable () async throws -> [Component]
    ) async throws -> [Component] {
        let task: Task<[Component], Error> = lock.withLock {
            if let existing = tasks[fileId] { return existing }
            let newTask = Task { try await fetch() }
            tasks[fileId] = newTask
            return newTask
        }
        do {
            return try await task.value
        } catch {
            // Evict failed tasks so subsequent callers can retry (e.g., transient 429 rate limit)
            lock.withLock { tasks[fileId] = nil }
            throw error
        }
    }
}
