import CoreGraphics
import Foundation

// MARK: - Models the touch screens report into

/// State for the touchscreen test. The screen draws `columns` x `rows` cells, colours the ones
/// in `painted`, and passes every touch location to `touch(at:in:)`. The core decides which cell
/// was hit and ignores touches inside a simulated dead zone.
@MainActor
public final class TouchGridModel: ObservableObject {
    public let columns: Int
    public let rows: Int
    /// Indices (row * columns + column) of the cells the user has painted.
    @Published public private(set) var painted: Set<Int> = []
    private let deadZones: [UnitRect]

    public init(columns: Int = 6, rows: Int = 12, deadZones: [UnitRect] = []) {
        self.columns = columns
        self.rows = rows
        self.deadZones = deadZones
    }

    public var cellCount: Int { columns * rows }
    public var isComplete: Bool { painted.count == cellCount }
    public var coverage: Double { Double(painted.count) / Double(cellCount) }

    public func isPainted(row: Int, column: Int) -> Bool {
        painted.contains(row * columns + column)
    }

    /// A touch at `point` inside a grid view of `size` (points, origin top-left).
    public func touch(at point: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        touch(x: Double(point.x / size.width), y: Double(point.y / size.height))
    }

    /// A touch in unit coordinates (0...1).
    public func touch(x: Double, y: Double) {
        guard (0..<1).contains(x), (0..<1).contains(y) else { return }
        if deadZones.contains(where: { $0.contains(x: x, y: y) }) { return }
        let index = Int(y * Double(rows)) * columns + Int(x * Double(columns))
        if !painted.contains(index) { painted.insert(index) }
    }
}

/// State for the multi-touch test. The screen reports how many fingers are down.
@MainActor
public final class TouchCountModel: ObservableObject {
    public let required: Int
    @Published public private(set) var current = 0
    @Published public private(set) var maximum = 0
    /// Simulated fault: the digitiser only ever sees this many touches.
    private let cap: Int?

    public init(required: Int = 3, cap: Int? = nil) {
        self.required = required
        self.cap = cap
    }

    public var isComplete: Bool { maximum >= required }

    public func update(touchCount: Int) {
        let seen = min(touchCount, cap ?? touchCount)
        current = seen
        maximum = max(maximum, seen)
    }
}

/// State for the 3D Touch test. The screen reports each touch's force.
@MainActor
public final class ForcePressModel: ObservableObject {
    /// Fraction of the maximum possible force that counts as a firm press.
    public static let threshold = 0.6
    /// Peak force seen, 0...1.
    @Published public private(set) var peak = 0.0
    /// Simulated fault: the force sensor reads zero.
    private let dead: Bool

    public init(dead: Bool = false) {
        self.dead = dead
    }

    public var isComplete: Bool { peak >= Self.threshold }

    public func update(force: CGFloat, maximumForce: CGFloat) {
        guard !dead, maximumForce > 0 else { return }
        peak = max(peak, min(1, Double(force / maximumForce)))
    }
}

// MARK: - Tests

/// The user paints a full-screen grid; cells that cannot be painted are dead zones.
@MainActor
final class TouchscreenTest: DiagnosticTest {
    let id = TestID.touchscreen
    let components: [ComponentID] = [.touchscreen]

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        let grid = TouchGridModel(deadZones: context.faults.touchDeadZones)
        try await context.present(.touchGrid(grid), finishWhen: { grid.isComplete })

        let missed = grid.cellCount - grid.painted.count
        return [ComponentResult(
            .touchscreen,
            missed == 0 ? .pass : .fail,
            evidence: .automated,
            measurements: [Measurement("Squares painted", "\(grid.painted.count) of \(grid.cellCount)")],
            note: missed == 0 ? nil : "\(missed) squares could not be painted"
        )]
    }
}

/// Three fingers on the screen at once.
@MainActor
final class MultiTouchTest: DiagnosticTest {
    let id = TestID.multiTouch
    let components: [ComponentID] = [.multiTouch]

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        let model = TouchCountModel(cap: context.faults.isBroken(.multiTouch) ? 1 : nil)
        try await context.present(.multiTouch(model), finishWhen: { model.isComplete })
        return [ComponentResult(
            .multiTouch, model.isComplete ? .pass : .fail, evidence: .automated,
            measurements: [Measurement("Most touches at once", "\(model.maximum)")],
            note: model.isComplete ? nil : "Only \(model.maximum) touch(es) detected at once"
        )]
    }
}

/// Press firmly; the touch force must reach the threshold.
@MainActor
final class ForceTouchTest: DiagnosticTest {
    let id = TestID.forceTouch
    let components: [ComponentID] = [.forceTouch]

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        let model = ForcePressModel(dead: context.faults.isBroken(.forceTouch))
        try await context.present(.forcePress(model), finishWhen: { model.isComplete })
        return [ComponentResult(
            .forceTouch, model.isComplete ? .pass : .fail, evidence: .automated,
            measurements: [Measurement("Peak force", String(format: "%.0f%%", model.peak * 100))],
            note: model.isComplete ? nil : "Press force never reached \(Int(ForcePressModel.threshold * 100))%"
        )]
    }
}
