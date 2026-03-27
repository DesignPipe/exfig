import FigmaAPI
import Foundation

/// Deduplicating cache for Figma Variables API responses.
///
/// Concurrent callers requesting the same `fileId` share a single in-flight `Task`.
/// First caller triggers the fetch; subsequent callers await the same result.
final class VariablesCache: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [String: Task<VariablesMeta, Error>] = [:]

    func get(
        fileId: String,
        fetch: @escaping @Sendable () async throws -> VariablesMeta
    ) async throws -> VariablesMeta {
        let task: Task<VariablesMeta, Error> = lock.withLock {
            if let existing = tasks[fileId] { return existing }
            let newTask = Task { try await fetch() }
            tasks[fileId] = newTask
            return newTask
        }
        return try await task.value
    }
}
