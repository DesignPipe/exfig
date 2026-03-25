import FigmaAPI
import Foundation
import Noora

/// Context for formatting retry messages.
struct RetryMessageContext {
    let configName: String
    let attempt: Int
    let maxAttempts: Int
    let error: Error
    let delay: TimeInterval
    let useColors: Bool
}

/// Formats and logs retry events for terminal output.
enum RetryLogger {
    /// Create a retry event handler that logs to terminal.
    /// - Parameters:
    ///   - ui: Terminal UI instance for output control.
    ///   - maxAttempts: Maximum retry attempts for display.
    /// - Returns: A retry event handler function.
    static func createHandler(
        ui: TerminalUI,
        maxAttempts: Int = 4
    ) -> RetryEventHandler {
        let useColors = ui.outputMode.useColors && TTYDetector.colorsEnabled

        return { configName, attempt, error, delay in
            // Skip logging in quiet mode
            guard ui.outputMode != .quiet else { return }

            let context = RetryMessageContext(
                configName: configName,
                attempt: attempt,
                maxAttempts: maxAttempts,
                error: error,
                delay: delay,
                useColors: useColors
            )

            print(formatRetryMessage(context))
        }
    }

    /// Format a retry message for display using TOON compact format.
    /// - Parameter context: Message context containing all formatting parameters.
    /// - Returns: Formatted message string.
    static func formatRetryMessage(_ context: RetryMessageContext) -> String {
        let errorDescription = describeError(context.error)
        let delayStr = formatDelay(context.delay)

        let formatter = ExFigWarningFormatter()
        let warning = ExFigWarning.retrying(
            attempt: context.attempt,
            maxAttempts: context.maxAttempts,
            error: errorDescription,
            delay: delayStr
        )

        let icon = context.useColors ? NooraUI.format(.accent("⚠")) : "⚠"
        var message = "\(icon) \(formatter.format(warning))"

        // Add config name prefix if not empty (for batch processing)
        if !context.configName.isEmpty {
            let prefix = context.useColors ? NooraUI.format(.muted(
                "[\(context.configName)]"
            )) : "[\(context.configName)]"
            message = "\(prefix) \(message)"
        }

        return message
    }

    /// Format a final failure message.
    /// - Parameters:
    ///   - error: The final error.
    ///   - maxAttempts: Maximum retry attempts.
    ///   - useColors: Whether to use ANSI colors.
    /// - Returns: Formatted failure message.
    static func formatFailureMessage(
        error: Error,
        maxAttempts: Int,
        useColors: Bool
    ) -> String {
        let icon = useColors ? NooraUI.format(.danger("✗")) : "✗"
        var message = "\(icon) "

        if let apiError = error as? FigmaAPIError {
            message += apiError.errorDescription ?? "Unknown error"
            if let suggestion = apiError.recoverySuggestion {
                let suggestionText = useColors ? NooraUI.format(.muted(suggestion)) : suggestion
                message += "\n   \(suggestionText)"
            }
        } else {
            message += "Failed after \(maxAttempts) retries: \(error.localizedDescription)"
        }

        return message
    }

    // MARK: - Private

    private static func describeError(_ error: Error) -> String {
        if let httpError = error as? HTTPError {
            return describeHTTPError(httpError)
        }

        if let urlError = error as? URLError {
            return describeURLError(urlError)
        }

        if let apiError = error as? FigmaAPIError {
            return apiError.errorDescription ?? "API error"
        }

        return "Error"
    }

    private static func describeHTTPError(_ error: HTTPError) -> String {
        switch error.statusCode {
        case 429: "Rate limited"
        case 500: "Server error (500)"
        case 502: "Bad gateway (502)"
        case 503: "Service unavailable (503)"
        case 504: "Gateway timeout (504)"
        default: "HTTP error (\(error.statusCode))"
        }
    }

    private static func describeURLError(_ error: URLError) -> String {
        switch error.code {
        case .timedOut: "Request timeout"
        case .networkConnectionLost: "Network connection lost"
        case .notConnectedToInternet: "No internet connection"
        default: "Network error"
        }
    }

    private static func formatDelay(_ delay: TimeInterval) -> String {
        if delay < 1.0 {
            return String(format: "%.0fms", delay * 1000)
        } else if delay < 60.0 {
            return String(format: "%.0fs", delay)
        } else {
            let minutes = Int(delay / 60)
            let seconds = Int(delay.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }
}
