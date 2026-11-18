import Foundation

/// Runs the diagnostic plan and publishes everything the test screens need.
/// This is the main object the UI observes. See docs/CONTRACT.md.
///
/// Guided flow:
/// ```
/// begin() ─▶ .ready ─startCurrentTest()─▶ .running(interaction) ─▶ .showingResult ─next()─▶ .ready (next test)
///              │                              │                         │                    or .finished
///              └──────── skip() ──────────────┴─▶ .showingResult        └─retry()─▶ .ready (same test)
/// ```
@MainActor
public final class TestRunner: ObservableObject {
    public enum Phase {
        /// No test selected. Call `begin()`.
        case idle
        /// Show `currentTest`'s title and instructions with Start and Skip buttons.
        case ready
        /// A test is running. Render the interaction.
        case running(TestInteraction)
        /// Show the result with Next and Retry buttons.
        case showingResult(TestResult)
        /// Every test has a result. Move on to the survey.
        case finished
    }

    @Published public private(set) var phase: Phase = .idle
    /// Progress of the running test, 0...1, or nil for a spinner.
    @Published public private(set) var progress: Double?
    /// The tests in this run, in order. Use for "Test 3 of 12" and the test bench list.
    @Published public private(set) var plan: [TestID] = []
    @Published public private(set) var currentIndex: Int?
    /// Latest result for each test that has run.
    @Published public private(set) var results: [TestID: TestResult] = [:]
    @Published public private(set) var device: DeviceProfile

    public let faults: FaultInjector
    public private(set) var mode: PlanMode
    public private(set) var includeTier2: Bool

    private var tests: [DiagnosticTest] = []
    private var task: Task<Void, Never>?
    /// Changes on every start and skip, so a stale test cannot touch the published state.
    private var runToken = UUID()
    private var pendingAnswer: Bool?
    private var interactionFinished = false

    public init(device: DeviceProfile, faults: FaultInjector, mode: PlanMode = .full, includeTier2: Bool = false) {
        self.device = device
        self.faults = faults
        self.mode = mode
        self.includeTier2 = includeTier2
        rebuildPlan()
    }

    /// For tests and previews: run exactly these tests.
    public init(device: DeviceProfile, faults: FaultInjector, tests: [DiagnosticTest]) {
        self.device = device
        self.faults = faults
        self.mode = .full
        self.includeTier2 = true
        self.tests = tests
        self.plan = tests.map(\.id)
    }

    // MARK: - Derived state

    public var currentTest: TestID? {
        currentIndex.map { plan[$0] }
    }

    /// Results in plan order, for the summary screen and the report.
    public var orderedResults: [TestResult] {
        plan.compactMap { results[$0] }
    }

    public var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    // MARK: - Setup

    /// Rebuild the plan, e.g. after the device or a developer option changes. Clears results.
    public func configure(device: DeviceProfile? = nil, mode: PlanMode? = nil, includeTier2: Bool? = nil) {
        if let device { self.device = device }
        if let mode { self.mode = mode }
        if let includeTier2 { self.includeTier2 = includeTier2 }
        rebuildPlan()
    }

    /// "Reset for next visitor": stop anything running and clear all results.
    public func reset() {
        cancelRunningTest()
        results = [:]
        currentIndex = nil
        progress = nil
        phase = .idle
    }

    private func rebuildPlan() {
        reset()
        tests = TestPlan.makeTests(for: device.capabilities, mode: mode, includeTier2: includeTier2)
        plan = tests.map(\.id)
    }

    // MARK: - Guided flow

    /// Go to the first test.
    public func begin() {
        cancelRunningTest()
        results = [:]
        go(to: 0)
    }

    public func startCurrentTest() {
        guard let index = currentIndex, !isRunning else { return }
        start(index)
    }

    /// Record the current test as not tested and show its result.
    public func skip() {
        guard let index = currentIndex else { return }
        switch phase {
        case .ready, .running:
            cancelRunningTest()
            let test = tests[index]
            finish(.notTested(test.id, components: test.components, evidence: test.id.evidence, note: "Skipped"))
        default:
            break
        }
    }

    /// Run the current test again (e.g. the room was too noisy).
    public func retry() {
        guard currentIndex != nil, case .showingResult = phase else { return }
        phase = .ready
    }

    /// Move to the next test, or to `.finished` after the last one.
    public func next() {
        guard let index = currentIndex, case .showingResult = phase else { return }
        go(to: index + 1)
    }

    /// Leave the test screen: stops a running test without recording it and returns to `.idle`.
    /// Results already recorded are kept.
    public func close() {
        cancelRunningTest()
        currentIndex = nil
        progress = nil
        phase = .idle
    }

    /// Test bench: run any test straight away, outside the guided order.
    public func run(_ id: TestID) {
        guard let index = plan.firstIndex(of: id) else { return }
        cancelRunningTest()
        currentIndex = index
        start(index)
    }

    // MARK: - Answers from the UI

    /// The user's answer to `.yesNo`.
    public func answer(_ yes: Bool) {
        pendingAnswer = yes
    }

    /// The user finished a full-screen interaction, or tapped "Nothing happened" while waiting.
    public func finishInteraction() {
        interactionFinished = true
    }

    // MARK: - Report

    public func makeReport(survey: SurveyAnswers, appVersion: String = Report.bundleAppVersion) -> Report {
        Report.make(device: device, results: orderedResults, survey: survey, faults: faults, appVersion: appVersion)
    }

    // MARK: - Internals

    private func go(to index: Int) {
        progress = nil
        if index < plan.count {
            currentIndex = index
            phase = .ready
        } else {
            currentIndex = nil
            phase = .finished
        }
    }

    private func start(_ index: Int) {
        let test = tests[index]
        let token = UUID()
        runToken = token
        progress = nil
        pendingAnswer = nil
        interactionFinished = false

        // Recorded now, so the report stays stamped even if the options are turned off later.
        let simulation = faults.isActive ? faults.activeDescriptions : nil
        let override = faults.override(for: test.id)
        if override != .real {
            let status: TestStatus = override == .forceFail ? .fail : .notTested
            let components = test.components.map {
                ComponentResult($0, status, evidence: test.id.evidence, note: "Developer override")
            }
            finish(TestResult(testID: test.id, components: components, override: override, simulation: simulation))
            return
        }

        phase = .running(.working("Running…"))
        let context = RunContext(runner: self, token: token)
        task = Task { [weak self] in
            var result: TestResult
            do {
                let components = try await test.run(context)
                result = TestResult(testID: test.id, components: components)
            } catch is CancellationError {
                result = .notTested(test.id, components: test.components, evidence: test.id.evidence, note: "Skipped")
            } catch {
                result = .notTested(test.id, components: test.components, evidence: test.id.evidence,
                                    note: "Error: \(error.localizedDescription)")
            }
            guard let self, self.runToken == token else { return }
            result.simulation = simulation
            self.finish(Self.fillMissing(result, expected: test.components, evidence: test.id.evidence))
        }
    }

    private func finish(_ result: TestResult) {
        task = nil
        progress = nil
        results[result.testID] = result
        phase = .showingResult(result)
    }

    private func cancelRunningTest() {
        runToken = UUID()
        task?.cancel()
        task = nil
    }

    static func fillMissing(_ result: TestResult, expected: [ComponentID], evidence: Evidence) -> TestResult {
        var result = result
        let reported = Set(result.components.map(\.component))
        for component in expected where !reported.contains(component) {
            result.components.append(ComponentResult(component, .notTested, evidence: evidence, note: "No result"))
        }
        return result
    }

    // MARK: - Context handed to the running test

    fileprivate func isCurrent(_ token: UUID) -> Bool { runToken == token }
    fileprivate func setPhase(_ phase: Phase, token: UUID) { if isCurrent(token) { self.phase = phase } }
    fileprivate func setProgress(_ value: Double?, token: UUID) { if isCurrent(token) { progress = value } }
    fileprivate func takeAnswer() -> Bool? { defer { pendingAnswer = nil }; return pendingAnswer }
    fileprivate func takeInteractionFinished() -> Bool { defer { interactionFinished = false }; return interactionFinished }
}

@MainActor
private final class RunContext: TestContext {
    private weak var runner: TestRunner?
    private let token: UUID
    private let pollInterval = 0.05

    init(runner: TestRunner, token: UUID) {
        self.runner = runner
        self.token = token
        self.device = runner.device
        self.faults = runner.faults
    }

    let device: DeviceProfile
    let faults: FaultInjector

    func show(_ interaction: TestInteraction) {
        runner?.setPhase(.running(interaction), token: token)
    }

    func setProgress(_ fraction: Double?) {
        runner?.setProgress(fraction, token: token)
    }

    func askYesNo(_ question: String) async throws -> Bool {
        _ = runner?.takeAnswer()
        show(.yesNo(question))
        while true {
            try checkStillCurrent()
            if let answer = runner?.takeAnswer() { return answer }
            try await sleep(seconds: pollInterval)
        }
    }

    func present(_ interaction: TestInteraction, finishWhen: @escaping () -> Bool) async throws {
        _ = runner?.takeInteractionFinished()
        show(interaction)
        while true {
            try checkStillCurrent()
            if runner?.takeInteractionFinished() == true || finishWhen() { return }
            try await sleep(seconds: pollInterval)
        }
    }

    func waitForAction(_ message: String, timeout: Double, until condition: @escaping () -> Bool) async throws -> Bool {
        _ = runner?.takeInteractionFinished()
        show(.waitingForAction(message))
        let start = Date()
        defer { setProgress(nil) }
        while true {
            try checkStillCurrent()
            if condition() { return true }
            let elapsed = Date().timeIntervalSince(start)
            if elapsed >= timeout || runner?.takeInteractionFinished() == true { return false }
            setProgress(max(0, 1 - elapsed / timeout))
            try await sleep(seconds: pollInterval)
        }
    }

    func sleep(seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        try checkStillCurrent()
    }

    func waitUntil(timeout: Double, _ condition: @escaping () -> Bool) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try await sleep(seconds: pollInterval)
        }
        return condition()
    }

    private func checkStillCurrent() throws {
        guard let runner, runner.isCurrent(token) else { throw CancellationError() }
    }
}
