import Foundation
import Noora

/// Manages multiple concurrent progress indicators
actor MultiProgressManager {
    /// State of a single progress item
    struct ProgressState {
        let id: UUID
        var label: String
        var current: Int
        var total: Int?
        var status: Status
        let startTime: Date

        enum Status {
            case running
            case succeeded
            case failed
        }
    }

    private var progressItems: [UUID: ProgressState] = [:]
    private var lineCount: Int = 0
    private let useColors: Bool
    private let useAnimations: Bool

    init(useColors: Bool = true, useAnimations: Bool = true) {
        self.useColors = useColors
        self.useAnimations = useAnimations
    }

    /// Create a new progress item
    func createProgress(label: String, total: Int? = nil) -> UUID {
        let id = UUID()
        progressItems[id] = ProgressState(
            id: id,
            label: label,
            current: 0,
            total: total,
            status: .running,
            startTime: Date()
        )
        render()
        return id
    }

    /// Update progress for an item
    func update(id: UUID, current: Int, message: String? = nil) {
        guard var item = progressItems[id] else { return }
        item.current = current
        if let msg = message {
            item.label = msg
        }
        progressItems[id] = item
        render()
    }

    /// Mark an item as completed
    func complete(id: UUID, success: Bool, message: String? = nil) {
        guard var item = progressItems[id] else { return }
        item.status = success ? .succeeded : .failed
        if let msg = message {
            item.label = msg
        }
        progressItems[id] = item
        render()
    }

    /// Remove a completed item from tracking
    func remove(id: UUID) {
        progressItems.removeValue(forKey: id)
        render()
    }

    /// Clear all progress items
    func clear() {
        if useAnimations, lineCount > 0 {
            // Move up and clear all lines
            var output = ""
            for _ in 0 ..< lineCount {
                output += ANSICodes.cursorUp(1)
                output += ANSICodes.clearLine
            }
            TerminalOutputManager.shared.writeDirect(output)
        }
        progressItems.removeAll()
        lineCount = 0
    }

    /// Render all progress items
    private func render() {
        guard useAnimations else {
            // Plain mode: don't render multi-line progress
            return
        }

        var output = ""

        // Move cursor up to clear previous render
        if lineCount > 0 {
            output += ANSICodes.cursorUp(lineCount)
        }

        let sortedItems = progressItems.values.sorted { $0.id.uuidString < $1.id.uuidString }

        for item in sortedItems {
            output += ANSICodes.clearLine

            let icon: String = switch item.status {
            case .running:
                useColors ? NooraUI.format(.primary("⠸")) : "⠸"
            case .succeeded:
                useColors ? NooraUI.format(.success("✓")) : "✓"
            case .failed:
                useColors ? NooraUI.format(.danger("✗")) : "✗"
            }

            if let total = item.total, total > 0 {
                let percentage = Double(item.current) / Double(total) * 100
                output += "\(icon) \(item.label) [\(item.current)/\(total)] \(String(format: "%.0f%%", percentage))\n"
            } else {
                output += "\(icon) \(item.label)\n"
            }
        }

        lineCount = sortedItems.count
        TerminalOutputManager.shared.writeDirect(output)
    }
}
