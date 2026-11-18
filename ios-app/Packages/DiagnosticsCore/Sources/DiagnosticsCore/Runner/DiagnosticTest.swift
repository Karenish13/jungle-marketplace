import Foundation

/// What the test screen should show while a test is running. The UI switches on this;
/// it never decides pass or fail itself.
public enum TestInteraction {
    /// The app is measuring by itself. Show the message and a spinner (or `progress`).
    case working(String)
    /// The app is waiting for the user to do something it detects (press a button, plug in a
    /// cable). Show the message, a "Nothing happened" button that calls
    /// `TestRunner.finishInteraction()` (records a fail), and Skip. `progress` counts down the time left.
    case waitingForAction(String)
    /// Show the question with Yes and No buttons; call `TestRunner.answer(_:)`.
    case yesNo(String)
    /// Show a full-screen grid drawn from the model and feed every touch into it.
    /// Show a "Can't fill the rest" button that calls `TestRunner.finishInteraction()`.
    case touchGrid(TouchGridModel)
    /// Show each colour full screen, advancing on tap. If `defect` is set, draw it on top of
    /// every colour (a simulated fault). After the last colour call `TestRunner.finishInteraction()`.
    case colourScreens([DisplayColour], defect: DisplayDefect?)
    /// A full-screen area that reports how many fingers are down, via `model.update(touchCount:)`.
    /// Needs a UIKit view with `isMultipleTouchEnabled`. "Can't do it" calls `finishInteraction()`.
    case multiTouch(TouchCountModel)
    /// A target to press hard. Report every touch's force via `model.update(force:maximumForce:)`
    /// (UITouch.force and maximumPossibleForce). "Can't do it" calls `finishInteraction()`.
    case forcePress(ForcePressModel)
    /// A live preview of the camera under test, with the message and `progress` under it.
    /// Draw it with an `AVCaptureVideoPreviewLayer` on `feed.session`. If `feed.isBlanked`,
    /// draw black instead: that camera is simulated as broken. Skip is the only button.
    case cameraPreview(String, CameraFeed)
}

/// A solid colour for the display test, as plain RGB so the core does not depend on SwiftUI.
public enum DisplayColour: String, CaseIterable, Sendable {
    case white, black, red, green, blue, grey

    public var rgb: (red: Double, green: Double, blue: Double) {
        switch self {
        case .white: return (1, 1, 1)
        case .black: return (0, 0, 0)
        case .red: return (1, 0, 0)
        case .green: return (0, 1, 0)
        case .blue: return (0, 0, 1)
        case .grey: return (0.5, 0.5, 0.5)
        }
    }
}

/// A simulated display fault for the screen to draw: a rectangle of one fixed colour.
public struct DisplayDefect: Hashable, Sendable {
    public var rect: UnitRect
    public var rgb: (red: Double, green: Double, blue: Double)

    public static func == (a: DisplayDefect, b: DisplayDefect) -> Bool {
        a.rect == b.rect && a.rgb == b.rgb
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(rect) }

    /// A stuck magenta column of pixels, visible on every test colour.
    public static let deadColumn = DisplayDefect(rect: UnitRect(x: 0.62, y: 0, width: 0.008, height: 1), rgb: (1, 0, 1))
}

/// What a running test can ask of the runner. Implemented by `TestRunner`; tests never touch the UI.
@MainActor
public protocol TestContext: AnyObject {
    var device: DeviceProfile { get }
    var faults: FaultInjector { get }

    /// Change what the screen shows. Returns immediately.
    func show(_ interaction: TestInteraction)
    /// 0...1, or nil for an indeterminate spinner.
    func setProgress(_ fraction: Double?)
    /// Shows `.yesNo` and waits for `TestRunner.answer(_:)`.
    func askYesNo(_ question: String) async throws -> Bool
    /// Shows the interaction and waits for `TestRunner.finishInteraction()` or until
    /// `finishWhen` returns true (checked about 20 times a second).
    func present(_ interaction: TestInteraction, finishWhen: @escaping () -> Bool) async throws
    /// Shows `.waitingForAction(message)` and waits until `condition` is true (returns true),
    /// or the timeout passes or the user taps "Nothing happened" (returns false).
    func waitForAction(_ message: String, timeout: Double, until condition: @escaping () -> Bool) async throws -> Bool
    /// Throws `CancellationError` if the user skips meanwhile.
    func sleep(seconds: Double) async throws
    /// Polls `condition` until it is true (returns true) or the timeout passes (returns false).
    func waitUntil(timeout: Double, _ condition: @escaping () -> Bool) async throws -> Bool
}

public extension TestContext {
    func present(_ interaction: TestInteraction) async throws {
        try await present(interaction, finishWhen: { false })
    }

    /// Shows a message with a progress bar that fills over `seconds`.
    func countdown(_ message: String, seconds: Double) async throws {
        show(.working(message))
        let steps = max(1, Int(seconds / 0.25))
        for step in 1...steps {
            setProgress(Double(step) / Double(steps))
            try await sleep(seconds: seconds / Double(steps))
        }
        setProgress(nil)
    }
}

/// One conforming type per test.
///
/// `run` returns one result per component. Throwing `CancellationError` (which every
/// `TestContext` wait does when the user skips) makes the runner record "not tested".
/// Components missing from the returned array are filled in as "not tested".
///
/// Every test must honour `context.faults.isBroken(_:)` for its components by feeding bad input
/// into its own detection code, never by returning a preset answer.
@MainActor
public protocol DiagnosticTest: AnyObject {
    var id: TestID { get }
    /// The components this test reports on, for this phone.
    var components: [ComponentID] { get }
    func run(_ context: TestContext) async throws -> [ComponentResult]
}
