// swiftlint:disable file_length type_body_length
import FigmaAPI
import Foundation
import Noora

/// Progress display for batch processing of multiple configs.
///
/// Displays multi-line progress with per-config status and rate limit information:
/// ```
/// Batch Export (3/5 configs)
/// ├─ [████████░░] ios-app.pkl       Colors: 45/50  Icons: 120/120 ✓
/// ├─ [██████░░░░] android-app.pkl   Colors: 30/50  Icons: 80/120
/// ├─ [░░░░░░░░░░] web-app.pkl       Waiting...
/// └─ Rate limit: 8.5 req/s (10 max)
/// ```
actor BatchProgressView {
    // MARK: - Config State

    /// State of a config being processed.
    struct ConfigState {
        let name: String
        var status: Status
        var exportProgress: ExportProgress
        var stepProgress: (completed: Int, total: Int)?
        var startTime: Date?

        enum Status {
            case pending
            case running
            case succeeded
            case failed(String)
        }

        struct ExportProgress {
            var colors: (current: Int, total: Int)?
            var icons: (current: Int, total: Int)?
            var images: (current: Int, total: Int)?
            var typography: (current: Int, total: Int)?
        }
    }

    // MARK: - Properties

    private var configStates: [String: ConfigState] = [:]
    private var configOrder: [String] = []
    private var lineCount: Int = 0
    private var rateLimiterStatus: RateLimiterStatus?
    private var batchStartTime: Date?

    // Log queue to serialize warning/error output and prevent race conditions
    private var logQueue: [String] = []
    private var isProcessingLogs = false

    private let useColors: Bool
    private let useAnimations: Bool
    private var cachedTerminalWidth: Int

    /// Progress bar width, dynamically calculated based on terminal width.
    private var progressWidth: Int {
        // Reserve space for: tree prefix (3) + status icon (2) + [] (2) + name column (26) + padding (5)
        let reservedWidth = 38
        let availableWidth = cachedTerminalWidth - reservedWidth
        // Progress bar between 10 and 30 characters
        return max(10, min(30, availableWidth / 4))
    }

    // MARK: - Initialization

    init(useColors: Bool = true, useAnimations: Bool = true) {
        self.useColors = useColors
        self.useAnimations = useAnimations
        cachedTerminalWidth = TTYDetector.terminalWidth
    }

    // MARK: - Config Management

    /// Register a config for progress tracking.
    func registerConfig(name: String) {
        if batchStartTime == nil {
            batchStartTime = Date()
        }
        configStates[name] = ConfigState(
            name: name,
            status: .pending,
            exportProgress: ConfigState.ExportProgress()
        )
        if !configOrder.contains(name) {
            configOrder.append(name)
        }
        render()
    }

    /// Mark a config as running.
    func startConfig(name: String) {
        guard var state = configStates[name] else { return }
        state.status = .running
        state.startTime = Date()
        configStates[name] = state
        render()
    }

    /// Update export progress for a config.
    func updateProgress(
        name: String,
        colors: (current: Int, total: Int)? = nil,
        icons: (current: Int, total: Int)? = nil,
        images: (current: Int, total: Int)? = nil,
        typography: (current: Int, total: Int)? = nil
    ) {
        guard var state = configStates[name] else { return }
        if let colors { state.exportProgress.colors = colors }
        if let icons { state.exportProgress.icons = icons }
        if let images { state.exportProgress.images = images }
        if let typography { state.exportProgress.typography = typography }
        configStates[name] = state
        render()
    }

    /// Set total number of export steps for a config (e.g. colors + icons + images = 3 steps).
    func setTotalSteps(name: String, total: Int) {
        guard var state = configStates[name] else { return }
        state.stepProgress = (completed: 0, total: total)
        configStates[name] = state
        render()
    }

    /// Mark an export step as completed and update the corresponding asset type progress.
    func completeExportStep(
        name: String,
        assetType: ConfigExecutionContext.AssetType,
        count: Int
    ) {
        guard var state = configStates[name] else { return }
        if var sp = state.stepProgress {
            sp.completed += 1
            state.stepProgress = sp
        }
        switch assetType {
        case .colors: state.exportProgress.colors = (count, count)
        case .icons: state.exportProgress.icons = (count, count)
        case .images: state.exportProgress.images = (count, count)
        case .typography: state.exportProgress.typography = (count, count)
        }
        configStates[name] = state
        render()
    }

    /// Mark a config as succeeded.
    func succeedConfig(name: String) {
        guard var state = configStates[name] else { return }
        state.status = .succeeded
        configStates[name] = state
        render()
    }

    /// Mark a config as failed.
    func failConfig(name: String, error: String) {
        guard var state = configStates[name] else { return }
        state.status = .failed(error)
        configStates[name] = state
        render()
    }

    // MARK: - Rate Limit Status

    /// Update the rate limiter status display.
    func updateRateLimiterStatus(_ status: RateLimiterStatus) {
        rateLimiterStatus = status
        render()
    }

    // MARK: - Terminal Resize

    /// Handle terminal resize by updating cached width and re-rendering.
    func handleTerminalResize() {
        let newWidth = TTYDetector.terminalWidth
        guard newWidth != cachedTerminalWidth else { return }
        cachedTerminalWidth = newWidth
        // Clear and re-render with new dimensions
        clear()
        render()
    }

    // MARK: - Rendering

    /// Clear the progress display.
    func clear() {
        guard useAnimations, lineCount > 0 else { return }

        // Move up and clear all lines
        var output = ""
        for _ in 0 ..< lineCount {
            output += ANSICodes.cursorUp(1)
            output += ANSICodes.clearLine
        }
        lineCount = 0
        TerminalOutputManager.shared.writeDirect(output)
    }

    /// Clear progress display temporarily for log output.
    /// This moves cursor up and clears lines without resetting lineCount,
    /// allowing render() to redraw the progress after the log message.
    func clearForLog() {
        guard useAnimations, lineCount > 0 else { return }

        // Move up and clear from cursor to end of screen
        TerminalOutputManager.shared.writeDirect(ANSICodes.cursorUp(lineCount))
        TerminalOutputManager.shared.writeDirect(ANSICodes.clearToEndOfScreen)
    }

    // MARK: - Serialized Log Output

    /// Queue a log message for coordinated output.
    /// Prevents race conditions when multiple warnings/errors are printed simultaneously.
    func queueLogMessage(_ message: String) {
        logQueue.append(message)
        processLogQueueIfNeeded()
    }

    /// Process queued logs one at a time to prevent interleaving.
    private func processLogQueueIfNeeded() {
        guard !isProcessingLogs, !logQueue.isEmpty else { return }
        isProcessingLogs = true

        // Clear progress display before printing logs
        clearForLog()

        // Output all queued logs
        while !logQueue.isEmpty {
            let message = logQueue.removeFirst()
            TerminalOutputManager.shared.writeDirect(message + "\n")
        }

        // Progress was cleared, cursor is at new position — reset lineCount before redraw
        lineCount = 0
        render()

        isProcessingLogs = false
    }

    /// Render the batch progress view.
    func render() {
        guard useAnimations else { return }

        var output = ""

        // Clear previous render
        if lineCount > 0 {
            output += ANSICodes.cursorUp(lineCount)
        }

        var lines: [String] = []

        // Config lines (header "Batch Export" is printed once from Batch.swift, outside animated area)
        let sortedConfigs = configOrder.compactMap { configStates[$0] }
        for config in sortedConfigs {
            let line = formatConfigLine(config, prefix: "├─")
            lines.append(line)
        }

        // Rate limit status line
        if let status = rateLimiterStatus {
            lines.append("├─ \(formatRateLimitText(status))")
        }

        // Footer: progress counter with step progress and elapsed time
        let completedConfigs = configStates.values.filter { isCompleted($0.status) }.count
        let totalConfigs = configStates.count
        let elapsed = batchStartTime.map { formatDuration(Date().timeIntervalSince($0)) } ?? "0s"

        // Aggregate step progress across all configs
        var completedSteps = 0
        var totalSteps = 0
        for state in configStates.values {
            if let sp = state.stepProgress {
                completedSteps += sp.completed
                totalSteps += sp.total
            }
        }

        var counterParts = ["\(completedConfigs)/\(totalConfigs) configs"]
        if totalSteps > 0 {
            counterParts.append("\(completedSteps)/\(totalSteps) steps")
        }
        counterParts.append(elapsed)
        let counterText = counterParts.joined(separator: " \u{2022} ")
        lines.append("└─ \(useColors ? NooraUI.format(.muted(counterText)) : counterText)")

        // Build output
        for line in lines {
            output += ANSICodes.clearLine
            output += line + "\n"
        }

        lineCount = lines.count
        TerminalOutputManager.shared.writeDirect(output)
    }

    // MARK: - Formatting Helpers

    private func isCompleted(_ status: ConfigState.Status) -> Bool {
        switch status {
        case .succeeded, .failed:
            true
        case .pending, .running:
            false
        }
    }

    private func formatConfigLine(_ config: ConfigState, prefix: String) -> String {
        let icon = statusIcon(config.status)
        let progressBar = formatProgressBar(config)
        let nameColumn = config.name.padding(toLength: 25, withPad: " ", startingAt: 0)
        let statusText = formatStatusText(config)

        return "\(prefix) \(icon) \(progressBar) \(nameColumn) \(statusText)"
    }

    private func statusIcon(_ status: ConfigState.Status) -> String {
        switch status {
        case .pending:
            useColors ? NooraUI.format(.muted("○")) : "○"
        case .running:
            useColors ? NooraUI.format(.primary("●")) : "●"
        case .succeeded:
            useColors ? NooraUI.format(.success("✓")) : "✓"
        case .failed:
            useColors ? NooraUI.format(.danger("✗")) : "✗"
        }
    }

    private func formatProgressBar(_ config: ConfigState) -> String {
        let percentage = calculateOverallProgress(config)
        let filled = Int(percentage * Double(progressWidth))
        let empty = progressWidth - filled

        let filledBar = String(repeating: "█", count: filled)
        let emptyBar = String(repeating: "░", count: empty)

        if useColors {
            return "[\(NooraUI.format(.primary(filledBar)))\(NooraUI.format(.muted(emptyBar)))]"
        }
        return "[\(filledBar)\(emptyBar)]"
    }

    private func calculateOverallProgress(_ config: ConfigState) -> Double {
        // Prefer step-level progress when available (batch mode)
        if let sp = config.stepProgress, sp.total > 0 {
            return Double(sp.completed) / Double(sp.total)
        }

        // Fallback to per-asset progress (download-level)
        var total = 0
        var completed = 0

        if let colors = config.exportProgress.colors {
            total += colors.total
            completed += colors.current
        }
        if let icons = config.exportProgress.icons {
            total += icons.total
            completed += icons.current
        }
        if let images = config.exportProgress.images {
            total += images.total
            completed += images.current
        }
        if let typography = config.exportProgress.typography {
            total += typography.total
            completed += typography.current
        }

        guard total > 0 else {
            switch config.status {
            case .succeeded:
                return 1.0
            case .failed, .pending:
                return 0.0
            case .running:
                return 0.1 // Show some progress when running
            }
        }

        return Double(completed) / Double(total)
    }

    /// Calculate estimated time remaining for a config based on progress
    private func calculateETA(_ config: ConfigState) -> TimeInterval? {
        guard case .running = config.status,
              let startTime = config.startTime
        else {
            return nil
        }

        let progress = calculateOverallProgress(config)
        guard progress > 0.1 else { return nil } // Need at least 10% data

        let elapsed = Date().timeIntervalSince(startTime)
        let estimatedTotal = elapsed / progress
        let remaining = estimatedTotal - elapsed

        return max(0, remaining)
    }

    /// Format duration as "Xs" or "Xm Ys"
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let sec = Int(seconds)
        if sec < 60 {
            return "\(sec)s"
        } else {
            let min = sec / 60
            let remainingSec = sec % 60
            return "\(min)m \(remainingSec)s"
        }
    }

    private func formatStatusText(_ config: ConfigState) -> String {
        switch config.status {
        case .pending:
            return useColors ? NooraUI.format(.muted("Waiting...")) : "Waiting..."
        case .running:
            var text = formatExportProgress(config.exportProgress)
            if let eta = calculateETA(config), eta > 1 {
                let etaStr = formatDuration(eta)
                text += useColors ? "  " + NooraUI.format(.muted("ETA: \(etaStr)")) : "  ETA: \(etaStr)"
            }
            return text
        case .succeeded:
            return formatExportProgress(config.exportProgress)
        case let .failed(error):
            let truncated = String(error.prefix(30))
            return useColors ? NooraUI.format(.danger(truncated)) : truncated
        }
    }

    private func formatExportProgress(_ progress: ConfigState.ExportProgress) -> String {
        var parts: [String] = []

        if let colors = progress.colors, colors.total > 0 {
            let status = colors.current >= colors.total
                ? (useColors ? NooraUI.format(.success("✓")) : "✓")
                : "\(colors.current)/\(colors.total)"
            parts.append("Colors: \(status)")
        }

        if let icons = progress.icons, icons.total > 0 {
            let status = icons.current >= icons.total
                ? (useColors ? NooraUI.format(.success("✓")) : "✓")
                : "\(icons.current)/\(icons.total)"
            parts.append("Icons: \(status)")
        }

        if let images = progress.images, images.total > 0 {
            let status = images.current >= images.total
                ? (useColors ? NooraUI.format(.success("✓")) : "✓")
                : "\(images.current)/\(images.total)"
            parts.append("Images: \(status)")
        }

        if let typography = progress.typography, typography.total > 0 {
            let status = typography.current >= typography.total
                ? (useColors ? NooraUI.format(.success("✓")) : "✓")
                : "\(typography.current)/\(typography.total)"
            parts.append("Typography: \(status)")
        }

        return parts.joined(separator: "  ")
    }

    private func formatRateLimitText(_ status: RateLimiterStatus) -> String {
        if status.isPaused {
            let retryStr = status.retryAfter.map { String(format: "%.0fs", $0) } ?? "unknown"
            let pausedMsg = "Rate limit: Paused (retry after \(retryStr))"
            return useColors
                ? NooraUI.format(.accent(pausedMsg))
                : pausedMsg
        } else {
            let rpm = String(format: "%.0f", status.requestsPerMinute)
            let pending = status.pendingRequestCount
            let pendingInfo = pending > 0 ? ", \(pending) queued" : ""
            return "Rate limit: \(rpm) req/min\(pendingInfo)"
        }
    }
}
