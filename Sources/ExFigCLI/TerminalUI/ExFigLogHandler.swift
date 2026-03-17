import Foundation
import Logging
import Noora

/// Custom log handler that routes output through TerminalUI
struct ExFigLogHandler: LogHandler {
    let label: String
    var logLevel: Logger.Level
    var metadata: Logger.Metadata = [:]
    private let outputMode: OutputMode

    init(label: String, logLevel: Logger.Level = .info, outputMode: OutputMode) {
        self.label = label
        self.logLevel = logLevel
        self.outputMode = outputMode
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    // swiftlint:disable:next function_parameter_count
    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        // Quiet mode: only show warnings and errors
        if outputMode == .quiet, level < .warning {
            return
        }

        // Batch mode: suppress info/debug to avoid corrupting progress display.
        // Warnings/errors are routed through BatchProgressView.queueLogMessage
        // which coordinates cursor position with the animated progress view.
        if let progressView = BatchSharedState.current?.progressView {
            if level < .warning { return }

            let formattedMessage: String
            if outputMode == .verbose {
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let fileName = URL(fileURLWithPath: file).lastPathComponent
                let levelStr = formatLevel(level)
                formattedMessage = "[\(levelStr)] \(timestamp) \(fileName):\(line) \(message)"
            } else {
                formattedMessage = formatMessage(level: level, message: message)
            }

            let semaphore = DispatchSemaphore(value: 0)
            Task {
                await progressView.queueLogMessage(formattedMessage)
                semaphore.signal()
            }
            semaphore.wait()
            return
        }

        let formattedMessage: String

        if outputMode == .verbose {
            // Verbose mode: include detailed info
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            let levelStr = formatLevel(level)
            formattedMessage = "[\(levelStr)] \(timestamp) \(fileName):\(line) \(message)"
        } else {
            // Normal/plain mode: simple message
            formattedMessage = formatMessage(level: level, message: message)
        }

        if outputMode == .mcp {
            // In MCP mode, write directly to stderr to avoid corrupting JSON-RPC on stdout
            FileHandle.standardError.write(Data("\(formattedMessage)\n".utf8))
        } else {
            TerminalOutputManager.shared.print(formattedMessage)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func formatLevel(_ level: Logger.Level) -> String {
        let levelText = switch level {
        case .trace: "TRACE"
        case .debug: "DEBUG"
        case .info: "INFO"
        case .notice: "NOTICE"
        case .warning: "WARNING"
        case .error: "ERROR"
        case .critical: "CRITICAL"
        }

        guard outputMode.useColors else {
            return levelText
        }

        switch level {
        case .trace, .debug:
            return NooraUI.format(.muted(levelText))
        case .info, .notice:
            return NooraUI.format(.primary(levelText))
        case .warning:
            return NooraUI.format(.accent(levelText))
        case .error, .critical:
            return NooraUI.format(.danger(levelText))
        }
    }

    private func formatMessage(level: Logger.Level, message: Logger.Message) -> String {
        guard outputMode.useColors else {
            return "\(message)"
        }

        switch level {
        case .warning:
            return NooraUI.format(.accent("⚠ \(message)"))
        case .error, .critical:
            return NooraUI.format(.danger("✗ \(message)"))
        default:
            return "\(message)"
        }
    }
}

// MARK: - LoggingSystem Bootstrap

enum ExFigLogging {
    /// Bootstrap the logging system with ExFig's custom handler
    static func bootstrap(outputMode: OutputMode) {
        LoggingSystem.bootstrap { label in
            let logLevel: Logger.Level = outputMode == .verbose ? .debug : .info
            return ExFigLogHandler(label: label, logLevel: logLevel, outputMode: outputMode)
        }
    }
}
