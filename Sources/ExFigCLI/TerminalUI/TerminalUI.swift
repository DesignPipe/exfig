// swiftlint:disable file_length
import ExFigCore
import Foundation

/// Main facade for terminal UI operations
final class TerminalUI: Sendable {
    let outputMode: OutputMode

    private let useColors: Bool
    private let useAnimations: Bool

    init(outputMode: OutputMode) {
        self.outputMode = outputMode
        useColors = outputMode.useColors && TTYDetector.colorsEnabled
        useAnimations = outputMode.useAnimations && TTYDetector.isTTY
    }

    // MARK: - Convenience Initializer

    /// Create TerminalUI from CLI flags
    static func create(verbose: Bool, quiet: Bool) -> TerminalUI {
        let mode = TTYDetector.effectiveMode(verbose: verbose, quiet: quiet)
        return TerminalUI(outputMode: mode)
    }

    // MARK: - Simple Output

    /// Print an info message
    func info(_ message: String) {
        guard outputMode != .quiet else { return }
        // Suppress in batch mode - progress view shows status
        if BatchSharedState.current?.progressView != nil { return }
        // Suppress when parent spinner is active (parallel entries)
        if TerminalOutputManager.shared.hasActiveAnimation { return }
        TerminalOutputManager.shared.print(NooraUI.formatInfo(message, useColors: useColors))
    }

    /// Print a success message
    func success(_ message: String) {
        guard outputMode != .quiet else { return }
        // Suppress in batch mode - progress view shows status
        if BatchSharedState.current?.progressView != nil { return }
        // Suppress when parent spinner is active (parallel entries)
        if TerminalOutputManager.shared.hasActiveAnimation { return }
        TerminalOutputManager.shared.print(NooraUI.formatSuccess(message, useColors: useColors))
    }

    /// Print a warning message (handles multi-line properly)
    func warning(_ message: String) {
        // Forward to warning collector when active (--report mode)
        // Direct sync call — no semaphore needed (Lock-based collector)
        WarningCollectorStorage.current?.add(message)

        // In batch mode, queue for coordinated output to prevent race conditions
        if let progressView = BatchSharedState.current?.progressView {
            let formatted = formatWarningForQueue(message)
            // Use semaphore to ensure log is processed before returning.
            // This prevents race conditions where updateProgress() calls render()
            // before the log message is queued, causing duplicate lines.
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                await progressView.queueLogMessage(formatted)
                semaphore.signal()
            }
            semaphore.wait()
            return
        }

        printWarning(message)
    }

    /// Internal helper to print warning message with formatting
    private func printWarning(_ message: String) {
        let formatted = NooraUI.formatMultilineWarning(message, useColors: useColors)
        for line in formatted.split(separator: "\n", omittingEmptySubsequences: false) {
            TerminalOutputManager.shared.print(String(line))
        }
    }

    /// Print a formatted ExFigWarning
    func warning(_ warning: ExFigWarning) {
        let formatter = ExFigWarningFormatter()
        let formattedMessage = formatter.format(warning)
        self.warning(formattedMessage)
    }

    /// Print an error message
    func error(_ message: String) {
        // In batch mode, queue for coordinated output to prevent race conditions
        if let progressView = BatchSharedState.current?.progressView {
            let formatted = formatErrorForQueue(message)
            // Use semaphore to ensure log is processed before returning.
            // This prevents race conditions where updateProgress() calls render()
            // before the log message is queued, causing duplicate lines.
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                await progressView.queueLogMessage(formatted)
                semaphore.signal()
            }
            semaphore.wait()
            return
        }

        printError(message)
    }

    /// Internal helper to print error message with formatting
    private func printError(_ message: String) {
        let formatted = NooraUI.formatMultilineError(message, useColors: useColors)
        for line in formatted.split(separator: "\n", omittingEmptySubsequences: false) {
            TerminalOutputManager.shared.print(String(line))
        }
    }

    /// Print a formatted LocalizedError with optional recovery suggestion
    func error(_ error: any LocalizedError) {
        let formatter = ExFigErrorFormatter()
        let formattedMessage = formatter.format(error)
        self.error(formattedMessage)
    }

    /// Print a formatted Error
    func error(_ error: any Error) {
        let formatter = ExFigErrorFormatter()
        let formattedMessage = formatter.format(error)
        self.error(formattedMessage)
    }

    /// Print a debug message (only in verbose mode)
    func debug(_ message: String) {
        guard outputMode == .verbose else { return }
        // Suppress in batch mode - progress view shows status
        if BatchSharedState.current?.progressView != nil { return }
        // Suppress when parent spinner is active (parallel entries)
        if TerminalOutputManager.shared.hasActiveAnimation { return }
        TerminalOutputManager.shared.print(NooraUI.formatDebug(message, useColors: useColors))
    }

    // MARK: - Batch Mode Log Formatting

    /// Format warning message for batch mode queue (includes icon and coloring)
    private func formatWarningForQueue(_ message: String) -> String {
        NooraUI.formatMultilineWarning(message, useColors: useColors)
    }

    /// Format error message for batch mode queue (includes icon and coloring)
    private func formatErrorForQueue(_ message: String) -> String {
        NooraUI.formatMultilineError(message, useColors: useColors)
    }

    // MARK: - Parallel Entry Wrapper

    /// Wrap exporter call in a parent spinner when processing multiple entries.
    /// All inner output (spinners, info, success) is suppressed via `hasActiveAnimation`.
    /// Warnings/errors still print through `TerminalOutputManager` coordination.
    func withParallelEntries<T: Sendable>(
        _ message: String,
        count: Int,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        guard count > 1 else {
            return try await operation()
        }
        return try await withSpinner(message, operation: operation)
    }

    // MARK: - Spinner Operations

    /// Execute an operation with a spinner
    func withSpinner<T: Sendable>(
        _ message: String,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        // Suppress in batch mode to avoid corrupting multi-line progress display
        if BatchSharedState.current?.progressView != nil {
            return try await operation()
        }

        // Parallel entry processing may overlap; nested spinners would
        // produce garbled ANSI output, so only the first spinner renders.
        if TerminalOutputManager.shared.hasActiveAnimation {
            return try await operation()
        }

        guard outputMode.showProgress else {
            // Quiet mode or plain mode without animations
            if outputMode != .quiet {
                TerminalOutputManager.shared.print(message)
            }
            return try await operation()
        }

        let spinner = Spinner(
            message: message,
            useColors: useColors,
            useAnimations: useAnimations
        )

        spinner.start()

        do {
            let result = try await operation()
            spinner.succeed()
            return result
        } catch {
            spinner.fail()
            throw error
        }
    }

    /// Execute an operation with a spinner and custom completion message
    func withSpinner<T: Sendable>(
        _ message: String,
        successMessage: String,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        // Suppress in batch mode to avoid corrupting multi-line progress display
        if BatchSharedState.current?.progressView != nil {
            return try await operation()
        }

        // See first withSpinner overload for rationale
        if TerminalOutputManager.shared.hasActiveAnimation {
            return try await operation()
        }

        guard outputMode.showProgress else {
            if outputMode != .quiet {
                TerminalOutputManager.shared.print(message)
            }
            let result = try await operation()
            if outputMode != .quiet {
                TerminalOutputManager.shared.print("✓ \(successMessage)")
            }
            return result
        }

        let spinner = Spinner(
            message: message,
            useColors: useColors,
            useAnimations: useAnimations
        )

        spinner.start()

        do {
            let result = try await operation()
            spinner.succeed(message: successMessage)
            return result
        } catch {
            spinner.fail()
            throw error
        }
    }

    /// Execute an operation with a spinner that shows batch progress (current/total)
    func withSpinnerProgress<T: Sendable>(
        _ message: String,
        operation: @Sendable @escaping (@escaping @Sendable (Int, Int) -> Void) async throws -> T
    ) async rethrows -> T {
        // Suppress in batch mode to avoid corrupting multi-line progress display
        if BatchSharedState.current?.progressView != nil {
            return try await operation { _, _ in }
        }

        // See first withSpinner overload for rationale
        if TerminalOutputManager.shared.hasActiveAnimation {
            return try await operation { _, _ in }
        }

        guard outputMode.showProgress else {
            if outputMode != .quiet {
                TerminalOutputManager.shared.print(message)
            }
            // Provide no-op progress callback in quiet/plain mode
            return try await operation { _, _ in }
        }

        let spinner = Spinner(
            message: message,
            useColors: useColors,
            useAnimations: useAnimations
        )

        spinner.start()

        do {
            let result = try await operation { current, total in
                spinner.update(message: "\(message) (\(current)/\(total) batches)")
            }
            spinner.succeed()
            return result
        } catch {
            spinner.fail()
            throw error
        }
    }

    // MARK: - Progress Bar Operations

    /// Execute an operation with a progress bar
    func withProgress<T: Sendable>(
        _ message: String,
        total: Int,
        operation: @Sendable (ProgressBar) async throws -> T
    ) async rethrows -> T {
        // Suppress in batch mode to avoid corrupting multi-line progress display
        if BatchSharedState.current?.progressView != nil {
            let silentProgress = ProgressBar(
                message: message,
                total: max(total, 1),
                useColors: false,
                useAnimations: false,
                isSilent: true
            )
            return try await operation(silentProgress)
        }

        // Suppress when another animation is active (parallel entries)
        if TerminalOutputManager.shared.hasActiveAnimation {
            let silentProgress = ProgressBar(
                message: message,
                total: max(total, 1),
                useColors: false,
                useAnimations: false,
                isSilent: true
            )
            return try await operation(silentProgress)
        }

        guard outputMode.showProgress, total > 0 else {
            if outputMode != .quiet {
                TerminalOutputManager.shared.print(message)
            }
            let dummyProgress = ProgressBar(
                message: message,
                total: max(total, 1),
                useColors: false,
                useAnimations: false
            )
            return try await operation(dummyProgress)
        }

        let progressBar = ProgressBar(
            message: message,
            total: total,
            useColors: useColors,
            useAnimations: useAnimations
        )

        progressBar.start()

        do {
            let result = try await operation(progressBar)
            progressBar.succeed()
            return result
        } catch {
            progressBar.fail()
            throw error
        }
    }

    // MARK: - Multi-Progress Operations

    /// Create a multi-progress manager for concurrent operations
    func createMultiProgress() -> MultiProgressManager {
        MultiProgressManager(useColors: useColors, useAnimations: useAnimations)
    }

    /// Create a batch progress view for batch processing
    func createBatchProgress() -> BatchProgressView {
        BatchProgressView(useColors: useColors, useAnimations: useAnimations)
    }

    /// Create a dispatch source for terminal resize events (SIGWINCH).
    /// - Parameter handler: Closure to call when terminal is resized.
    /// - Returns: The dispatch source that must be retained while monitoring.
    func createResizeSource(_ handler: @escaping @Sendable () -> Void) -> DispatchSourceSignal? {
        guard useAnimations else { return nil }

        #if os(macOS) || os(Linux)
            // Ignore the default SIGWINCH handler
            signal(SIGWINCH, SIG_IGN)

            let source = DispatchSource.makeSignalSource(signal: SIGWINCH, queue: .main)
            source.setEventHandler {
                handler()
            }
            source.resume()
            return source
        #else
            return nil
        #endif
    }

    // MARK: - Cursor Control

    /// Hide the terminal cursor
    func hideCursor() {
        guard useAnimations else { return }
        print(ANSICodes.hideCursor, terminator: "")
        ANSICodes.flushStdout()
    }

    /// Show the terminal cursor
    func showCursor() {
        guard useAnimations else { return }
        print(ANSICodes.showCursor, terminator: "")
        ANSICodes.flushStdout()
    }

    /// Ensure cursor is visible (call on cleanup/exit)
    func cleanup() {
        showCursor()
    }
}

// MARK: - Signal Handling

extension TerminalUI {
    /// Install signal handlers to restore cursor on interruption
    func installSignalHandlers() {
        guard useAnimations else { return }

        signal(SIGINT) { _ in
            print(ANSICodes.showCursor, terminator: "")
            ANSICodes.flushStdout()
            exit(130)
        }

        signal(SIGTERM) { _ in
            print(ANSICodes.showCursor, terminator: "")
            ANSICodes.flushStdout()
            exit(143)
        }
    }
}
