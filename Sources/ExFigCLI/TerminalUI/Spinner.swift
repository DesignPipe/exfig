import Foundation
import Noora

/// Animated spinner for terminal progress indication.
/// Uses a dedicated high-priority DispatchQueue to ensure smooth animation
/// regardless of Swift concurrency thread pool load.
final class Spinner: @unchecked Sendable {
    /// Spinner animation frames (Braille pattern)
    private static let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    /// Animation interval (80ms = 12.5 FPS)
    private static let intervalMs: Int = 80

    /// Dedicated high-priority queue for spinner rendering
    private static let renderQueue = DispatchQueue(
        label: "com.exfig.spinner",
        qos: .userInteractive
    )

    private struct State {
        var message: String
        var isRunning = false
        var frameIndex = 0
    }

    private let state: Lock<State>
    // Timer is not Sendable, so we keep it separate and only access from renderQueue
    private var timer: DispatchSourceTimer?
    private let useColors: Bool
    private let useAnimations: Bool

    private var message: String {
        get { state.withLock { $0.message } }
        set { state.withLock { $0.message = newValue } }
    }

    private var isRunning: Bool {
        get { state.withLock { $0.isRunning } }
        set { state.withLock { $0.isRunning = newValue } }
    }

    init(message: String, useColors: Bool = true, useAnimations: Bool = true) {
        state = Lock(State(message: message))
        self.useColors = useColors
        self.useAnimations = useAnimations
    }

    /// Start the spinner animation
    func start() {
        guard !isRunning else { return }
        isRunning = true

        let initialMessage = message
        let initialFrame = Self.frames[0]
        let coloredFrame = useColors ? NooraUI.format(.primary(initialFrame)) : initialFrame

        // Set animation flag and initial frame synchronously BEFORE dispatching
        // This ensures log messages see the animation state immediately
        if useAnimations {
            TerminalOutputManager.shared.startAnimation(initialFrame: "\(coloredFrame) \(initialMessage)")

            Self.renderQueue.async { [self] in
                TerminalOutputManager.shared.writeDirect(ANSICodes.hideCursor)
                // First frame already rendered by startAnimation(), start timer for next frames

                let timer = DispatchSource.makeTimerSource(queue: Self.renderQueue)
                timer.schedule(
                    deadline: .now() + .milliseconds(Self.intervalMs),
                    repeating: .milliseconds(Self.intervalMs)
                )
                timer.setEventHandler { [weak self] in
                    self?.render()
                }
                self.timer = timer
                timer.resume()
            }
        }
        // Non-animated mode: no start output — stop() prints the final result
    }

    /// Update the spinner message
    func update(message: String) {
        self.message = message
        if !useAnimations {
            Self.renderQueue.async {
                TerminalOutputManager.shared.writeDirect("\(message)\n")
            }
        }
    }

    /// Stop the spinner with success state
    func succeed(message: String? = nil) {
        stop(success: true, message: message)
    }

    /// Stop the spinner with failure state
    func fail(message: String? = nil) {
        stop(success: false, message: message)
    }

    /// Stop the spinner
    private func stop(success: Bool, message: String?) {
        guard isRunning else { return }
        isRunning = false

        // Stop animation state synchronously so subsequent print() calls don't coordinate
        TerminalOutputManager.shared.hasActiveAnimation = false
        TerminalOutputManager.shared.clearAnimationState()

        // Cancel timer synchronously on render queue
        Self.renderQueue.sync {
            timer?.cancel()
            timer = nil
        }

        let finalMessage = message ?? self.message
        let successIcon = useColors ? NooraUI.format(.success("✓")) : "✓"
        let failIcon = useColors ? NooraUI.format(.danger("✗")) : "✗"
        let icon = success ? successIcon : failIcon

        if useAnimations {
            TerminalOutputManager.shared.writeDirect(
                "\(ANSICodes.carriageReturn)\(ANSICodes.clearToEndOfLine)\(icon) \(finalMessage)\n"
            )
            TerminalOutputManager.shared.writeDirect(ANSICodes.showCursor)
        } else {
            TerminalOutputManager.shared.writeDirect("\(icon) \(finalMessage)\n")
        }
    }

    /// Render a single frame of the spinner
    private func render() {
        let (currentMessage, currentFrameIndex) = state.withLock { state -> (String, Int) in
            guard state.isRunning else { return ("", 0) }
            let msg = state.message
            let idx = state.frameIndex
            state.frameIndex += 1
            return (msg, idx)
        }
        guard !currentMessage.isEmpty else { return }

        let frame = Self.frames[currentFrameIndex % Self.frames.count]
        let coloredFrame = useColors ? NooraUI.format(.primary(frame)) : frame
        TerminalOutputManager.shared.writeAnimationFrame("\(coloredFrame) \(currentMessage)")
    }
}
