import Noora

/// Adapter for Noora design system.
///
/// Provides a shared Noora instance with default theme for consistent
/// terminal text formatting across the CLI.
///
/// ## Usage
/// ```swift
/// let text: TerminalText = "Status: \(.success("OK"))"
/// print(NooraUI.format(text))
/// ```
enum NooraUI {
    /// Shared Noora instance with default theme.
    static let shared = Noora()

    /// Format TerminalText to a String with ANSI colors.
    /// - Parameter text: Semantic terminal text to format
    /// - Returns: String with ANSI escape codes for terminal display
    static func format(_ text: TerminalText) -> String {
        shared.format(text)
    }

    /// Format a single TerminalText component to a String with ANSI colors.
    /// - Parameter component: Semantic component to format (e.g. `.primary("text")`)
    /// - Returns: String with ANSI escape codes for terminal display
    static func format(_ component: TerminalText.Component) -> String {
        shared.format("\(component)")
    }

    // MARK: - Convenience Methods

    /// Format a success message with checkmark icon.
    /// - Parameters:
    ///   - message: The message to display
    ///   - useColors: Whether to apply colors
    /// - Returns: Formatted string with success icon
    static func formatSuccess(_ message: String, useColors: Bool) -> String {
        guard useColors else { return "✓ \(message)" }
        let text: TerminalText = "\(.success("✓")) \(message)"
        return format(text)
    }

    /// Format an error message with cross icon.
    /// - Parameters:
    ///   - message: The message to display
    ///   - useColors: Whether to apply colors
    /// - Returns: Formatted string with error icon
    static func formatError(_ message: String, useColors: Bool) -> String {
        guard useColors else { return "✗ \(message)" }
        let text: TerminalText = "\(.danger("✗")) \(.danger(message))"
        return format(text)
    }

    /// Format a warning message with warning icon.
    /// - Parameters:
    ///   - message: The message to display
    ///   - useColors: Whether to apply colors
    /// - Returns: Formatted string with warning icon
    static func formatWarning(_ message: String, useColors: Bool) -> String {
        guard useColors else { return "⚠ \(message)" }
        let text: TerminalText = "\(.accent("⚠")) \(.accent(message))"
        return format(text)
    }

    /// Format an info message with primary color.
    /// - Parameters:
    ///   - message: The message to display
    ///   - useColors: Whether to apply colors
    /// - Returns: Formatted string
    static func formatInfo(_ message: String, useColors: Bool) -> String {
        guard useColors else { return message }
        let text: TerminalText = "\(.primary(message))"
        return format(text)
    }

    /// Format a debug message with muted prefix.
    /// - Parameters:
    ///   - message: The message to display
    ///   - useColors: Whether to apply colors
    /// - Returns: Formatted string with debug prefix
    static func formatDebug(_ message: String, useColors: Bool) -> String {
        guard useColors else { return "[DEBUG] \(message)" }
        let text: TerminalText = "\(.muted("[DEBUG]")) \(message)"
        return format(text)
    }

    /// Format multi-line error message with proper indentation.
    /// - Parameters:
    ///   - message: The message (may contain newlines)
    ///   - useColors: Whether to apply colors
    /// - Returns: Formatted string with error icon and indented lines
    static func formatMultilineError(_ message: String, useColors: Bool) -> String {
        let lines = message.split(separator: "\n", omittingEmptySubsequences: false)
        return lines.enumerated().map { index, line in
            let lineStr = String(line)
            if index == 0 {
                return formatError(lineStr, useColors: useColors)
            } else {
                guard useColors else { return "  \(lineStr)" }
                let text: TerminalText = "  \(.danger(lineStr))"
                return format(text)
            }
        }.joined(separator: "\n")
    }

    /// Format multi-line warning message with proper indentation.
    /// - Parameters:
    ///   - message: The message (may contain newlines)
    ///   - useColors: Whether to apply colors
    /// - Returns: Formatted string with warning icon and indented lines
    static func formatMultilineWarning(_ message: String, useColors: Bool) -> String {
        let lines = message.split(separator: "\n", omittingEmptySubsequences: false)
        return lines.enumerated().map { index, line in
            let lineStr = String(line)
            if index == 0 {
                return formatWarning(lineStr, useColors: useColors)
            } else {
                guard useColors else { return "  \(lineStr)" }
                let text: TerminalText = "  \(.accent(lineStr))"
                return format(text)
            }
        }.joined(separator: "\n")
    }

    // MARK: - Link Formatting

    /// Format a clickable link with underline and primary color.
    /// - Parameters:
    ///   - text: The link text to display
    ///   - useColors: Whether to apply colors
    /// - Returns: Formatted string with ANSI underline and primary color
    static func formatLink(_ text: String, useColors: Bool) -> String {
        guard useColors else { return text }
        return "\u{001B}[4m\(format(.primary(text)))\u{001B}[24m"
    }

    // MARK: - Interactive Prompts

    /// Prompt the user for text input with optional validation.
    /// - Parameters:
    ///   - title: Optional title above the prompt
    ///   - prompt: The question text
    ///   - description: Optional description for context
    ///   - collapseOnAnswer: Whether to collapse after input (default: true)
    ///   - validationRules: Validation rules applied to input
    /// - Returns: The user's text input
    static func textPrompt(
        title: TerminalText? = nil,
        prompt: TerminalText,
        description: TerminalText? = nil,
        collapseOnAnswer: Bool = true,
        validationRules: [any ValidatableRule] = []
    ) -> String {
        shared.textPrompt(
            title: title,
            prompt: prompt,
            description: description,
            collapseOnAnswer: collapseOnAnswer,
            validationRules: validationRules
        )
    }

    /// Prompt the user to select a single option from a list.
    /// - Parameters:
    ///   - title: Optional title above the prompt
    ///   - question: The question text
    ///   - options: Array of options to choose from
    ///   - description: Optional description for context
    ///   - collapseOnSelection: Whether to collapse after selection (default: true)
    /// - Returns: The selected option
    static func singleChoicePrompt<T: Equatable & CustomStringConvertible>(
        title: TerminalText? = nil,
        question: TerminalText,
        options: [T],
        description: TerminalText? = nil,
        collapseOnSelection: Bool = true
    ) -> T {
        shared.singleChoicePrompt(
            title: title,
            question: question,
            options: options,
            description: description,
            collapseOnSelection: collapseOnSelection
        )
    }

    /// Prompt the user with a yes/no question.
    /// - Parameters:
    ///   - title: Optional title above the prompt
    ///   - question: The question text
    ///   - defaultAnswer: Default answer (default: true)
    ///   - description: Optional description for context
    ///   - collapseOnSelection: Whether to collapse after selection (default: true)
    /// - Returns: true for yes, false for no
    static func yesOrNoPrompt(
        title: TerminalText? = nil,
        question: TerminalText,
        defaultAnswer: Bool = true,
        description: TerminalText? = nil,
        collapseOnSelection: Bool = true
    ) -> Bool {
        shared.yesOrNoChoicePrompt(
            title: title,
            question: question,
            defaultAnswer: defaultAnswer,
            description: description,
            collapseOnSelection: collapseOnSelection
        )
    }

    /// Prompt the user to select multiple options from a list.
    /// - Parameters:
    ///   - title: Optional title above the prompt
    ///   - question: The question text
    ///   - options: Array of options to choose from
    ///   - description: Optional description for context
    ///   - collapseOnSelection: Whether to collapse after selection (default: true)
    ///   - minLimit: Minimum number of selections required (default: unlimited)
    /// - Returns: Array of selected options
    static func multipleChoicePrompt<T: Equatable & CustomStringConvertible>(
        title: TerminalText? = nil,
        question: TerminalText,
        options: [T],
        description: TerminalText? = nil,
        collapseOnSelection: Bool = true,
        minLimit: MultipleChoiceLimit = .unlimited
    ) -> [T] {
        shared.multipleChoicePrompt(
            title: title,
            question: question,
            options: options,
            description: description,
            collapseOnSelection: collapseOnSelection,
            minLimit: minLimit
        )
    }

    // MARK: - Progress Components

    /// Execute an async operation with a Noora progress bar (0-100%).
    ///
    /// Use this for operations with known completion percentage.
    /// For indeterminate progress, use the custom `TerminalUI.withSpinner()` instead.
    ///
    /// - Note: This renders directly via Noora, bypassing `TerminalOutputManager`.
    ///   Use only for standalone operations, not during batch mode or concurrent animations.
    ///
    /// - Parameters:
    ///   - message: Initial message shown during progress
    ///   - successMessage: Message shown on successful completion (optional)
    ///   - errorMessage: Message shown on failure (optional)
    ///   - operation: Async closure receiving an `updateProgress(Double)` callback (0.0 to 1.0)
    /// - Returns: The result of the operation
    static func progressBarStep<T>(
        message: String,
        successMessage: String? = nil,
        errorMessage: String? = nil,
        operation: @escaping (@escaping (Double) -> Void) async throws -> T
    ) async throws -> T {
        try await shared.progressBarStep(
            message: message,
            successMessage: successMessage,
            errorMessage: errorMessage,
            task: operation
        )
    }

    /// Execute an async operation with a Noora spinner and updateable message.
    ///
    /// Use this for operations where you want to update the status message dynamically.
    /// For simple indeterminate progress, prefer `TerminalUI.withSpinner()` which integrates
    /// with batch mode and output coordination.
    ///
    /// - Note: This renders directly via Noora, bypassing `TerminalOutputManager`.
    ///   Use only for standalone operations, not during batch mode or concurrent animations.
    ///
    /// - Parameters:
    ///   - message: Initial message shown with spinner
    ///   - successMessage: Message shown on successful completion (optional)
    ///   - errorMessage: Message shown on failure (optional)
    ///   - showSpinner: Whether to show animated spinner (default: true)
    ///   - operation: Async closure receiving an `updateMessage(String)` callback
    /// - Returns: The result of the operation
    static func progressStep<T>(
        message: String,
        successMessage: String? = nil,
        errorMessage: String? = nil,
        showSpinner: Bool = true,
        operation: @escaping ((String) -> Void) async throws -> T
    ) async throws -> T {
        try await shared.progressStep(
            message: message,
            successMessage: successMessage,
            errorMessage: errorMessage,
            showSpinner: showSpinner,
            task: operation
        )
    }
}
