import Foundation

/// A raw value a test measured, kept in the report as evidence (e.g. "Peak frequency" = "1002 Hz").
public struct Measurement: Codable, Hashable, Sendable {
    public var name: String
    public var value: String

    public init(_ name: String, _ value: String) {
        self.name = name
        self.value = value
    }
}

/// The result for one component.
public struct ComponentResult: Codable, Hashable, Sendable {
    public var component: ComponentID
    public var status: TestStatus
    public var evidence: Evidence
    public var measurements: [Measurement]
    /// Short human-readable reason, mainly for failures ("12 of 96 squares never touched").
    public var note: String?

    public init(
        _ component: ComponentID,
        _ status: TestStatus,
        evidence: Evidence,
        measurements: [Measurement] = [],
        note: String? = nil
    ) {
        self.component = component
        self.status = status
        self.evidence = evidence
        self.measurements = measurements
        self.note = note
    }
}

/// The result of running one test. A test can report on several components
/// (the camera test reports one result per lens).
public struct TestResult: Codable, Hashable, Sendable, Identifiable {
    public var testID: TestID
    public var components: [ComponentResult]
    public var finishedAt: Date
    /// Set when a developer override replaced the real result.
    public var override: ResultOverride?
    /// The developer options that were active when this test ran (`FaultInjector.activeDescriptions`),
    /// or nil if none were. The report's "simulated" stamp is built from these, so clearing the
    /// options after a run cannot remove it.
    public var simulation: [String]?

    public var id: TestID { testID }

    public init(testID: TestID, components: [ComponentResult], finishedAt: Date = Date(),
                override: ResultOverride? = nil, simulation: [String]? = nil) {
        self.testID = testID
        self.components = components
        self.finishedAt = finishedAt
        self.override = override
        self.simulation = simulation
    }

    /// Fail if any component failed, pass if every component passed, otherwise not tested.
    public var status: TestStatus {
        if components.contains(where: { $0.status == .fail }) { return .fail }
        if !components.isEmpty && components.allSatisfy({ $0.status == .pass }) { return .pass }
        return .notTested
    }

    /// Every component marked not tested, e.g. when the user skips.
    public static func notTested(_ testID: TestID, components: [ComponentID], evidence: Evidence, note: String) -> TestResult {
        TestResult(testID: testID, components: components.map {
            ComponentResult($0, .notTested, evidence: evidence, note: note)
        })
    }
}
