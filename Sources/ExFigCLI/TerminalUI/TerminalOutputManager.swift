import Foundation

/// Centralized manager for all terminal output.
/// Coordinates between spinner/progress animations and log messages.
/// All terminal output MUST go through this manager to prevent race conditions.
final class TerminalOutputManager: @unchecked Sendable {
    static let shared = TerminalOutputManager()

    private struct State {
        var hasActiveAnimation = false
        var lastAnimationLine: String = ""
        var usesStderr = false
    }

    private let state = Lock(State())

    private init() {}

    /// Configure output to use stderr (for MCP mode where stdout is reserved for JSON-RPC).
    func setStderrMode(_ enabled: Bool) {
        state.withLock { $0.usesStderr = enabled }
    }

    var hasActiveAnimation: Bool {
        get { state.withLock { $0.hasActiveAnimation } }
        set { state.withLock { $0.hasActiveAnimation = newValue } }
    }

    /// Start an animation with initial frame. Sets flag, stores frame, and renders it atomically.
    /// Call this synchronously when starting spinner/progress to ensure immediate coordination.
    func startAnimation(initialFrame: String) {
        state.withLock { state in
            state.hasActiveAnimation = true
            state.lastAnimationLine = initialFrame
            // Render initial frame immediately so it's visible before any logs arrive
            writeUnsafe(initialFrame, stderr: state.usesStderr)
        }
    }

    /// Print message, coordinating with active animations.
    /// If an animation is active, clears the current line first, then redraws animation.
    func print(_ message: String) {
        state.withLock { state in
            let stderr = state.usesStderr
            if state.hasActiveAnimation {
                // Clear current line before printing
                writeUnsafe("\(ANSICodes.carriageReturn)\(ANSICodes.clearToEndOfLine)", stderr: stderr)
                // Print message on new line
                writeUnsafe("\(message)\n", stderr: stderr)
                // Redraw the animation line immediately to prevent flicker
                if !state.lastAnimationLine.isEmpty {
                    writeUnsafe(state.lastAnimationLine, stderr: stderr)
                }
            } else {
                writeUnsafe("\(message)\n", stderr: stderr)
            }
        }
    }

    /// Write animation frame. Called by Spinner/ProgressBar.
    /// This tracks the current animation line for redrawing after log messages.
    func writeAnimationFrame(_ frame: String) {
        state.withLock { state in
            state.lastAnimationLine = frame
            writeUnsafe(
                "\(ANSICodes.carriageReturn)\(ANSICodes.clearToEndOfLine)\(frame)",
                stderr: state.usesStderr
            )
        }
    }

    /// Write raw output without coordination (for cursor show/hide, final messages).
    func writeDirect(_ string: String) {
        state.withLock { state in
            writeUnsafe(string, stderr: state.usesStderr)
        }
    }

    /// Clear animation state when animation stops.
    func clearAnimationState() {
        state.withLock { state in
            state.lastAnimationLine = ""
        }
    }

    /// Direct write to the configured output handle, bypassing Swift's print buffering.
    /// Must be called within lock for thread safety — no additional locking here.
    private func writeUnsafe(_ string: String, stderr: Bool) {
        let handle = stderr ? FileHandle.standardError : FileHandle.standardOutput
        handle.write(Data(string.utf8))
    }
}
