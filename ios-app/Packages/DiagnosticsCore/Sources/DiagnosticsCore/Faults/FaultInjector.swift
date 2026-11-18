import Foundation

/// A rectangle in unit coordinates (0...1 on both axes, origin top-left).
public struct UnitRect: Codable, Hashable, Sendable {
    public var x, y, width, height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }

    public func contains(x px: Double, y py: Double) -> Bool {
        px >= x && px < x + width && py >= y && py < y + height
    }

    /// Bottom-right quarter of the screen: the simulated "cracked corner" touch dead zone.
    public static let bottomRightQuarter = UnitRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
}

/// One-tap presets on the developer screen.
public enum FaultScenario: String, CaseIterable, Sendable {
    case healthy, crackedScreen, partsDonor

    public var title: String {
        switch self {
        case .healthy: return "Healthy"
        case .crackedScreen: return "Cracked screen"
        case .partsDonor: return "Parts donor"
        }
    }

    /// Components the scenario marks as broken.
    public var brokenComponents: Set<ComponentID> {
        switch self {
        case .healthy: return []
        case .crackedScreen: return [.touchscreen, .display]
        case .partsDonor: return [.touchscreen, .loudspeaker, .rearWideCamera]
        }
    }

    /// Survey answers that go with the scenario, for "fill survey" on the developer screen.
    public var sampleSurvey: SurveyAnswers {
        switch self {
        case .healthy: return .sampleHealthy
        case .crackedScreen:
            var s = SurveyAnswers.sampleHealthy
            s.screen = .poor
            s.notes = "Screen cracked; everything else works."
            return s
        case .partsDonor: return .samplePartsDonor
        }
    }
}

/// Developer options for simulating a bad phone.
///
/// The main tool is `broken`: every test checks it and feeds bad input into its real
/// detection code (a black camera frame, a silent speaker, a button press that never
/// registers), so the demo shows the app catching a fault. `overrides` replace a whole
/// test's result without running it. Any active option stamps the report as simulated.
@MainActor
public final class FaultInjector: ObservableObject {
    /// Components that behave as if broken.
    @Published public var broken: Set<ComponentID> = []
    /// Tests not in the dictionary run for real.
    @Published public var overrides: [TestID: ResultOverride] = [:]
    /// Pretend to be another model, e.g. "iPhone9,1". Re-run device detection after changing it.
    @Published public var deviceOverride: String?
    /// Expo option: use "did you hear it?" instead of measuring audio.
    @Published public var forceUserConfirmedAudio = false

    public init() {}

    // MARK: Broken components

    public func isBroken(_ component: ComponentID) -> Bool { broken.contains(component) }

    public func setBroken(_ component: ComponentID, _ isBroken: Bool) {
        if isBroken { broken.insert(component) } else { broken.remove(component) }
    }

    /// The touchscreen dead zone, when the touchscreen is broken.
    public var touchDeadZones: [UnitRect] { isBroken(.touchscreen) ? [.bottomRightQuarter] : [] }

    // MARK: Result overrides

    public func override(for test: TestID) -> ResultOverride {
        overrides[test] ?? .real
    }

    public func setOverride(_ value: ResultOverride, for test: TestID) {
        overrides[test] = value == .real ? nil : value
    }

    // MARK: State

    /// True when anything would change results. `forceUserConfirmedAudio` is excluded because
    /// it only changes how a test asks, not what it reports.
    public var isActive: Bool {
        !broken.isEmpty || !overrides.isEmpty || deviceOverride != nil
    }

    /// Lines for the "Demo: simulated results" stamp.
    public var activeDescriptions: [String] {
        var lines: [String] = []
        if !broken.isEmpty {
            let names = ComponentID.allCases.filter(broken.contains).map(\.displayName)
            lines.append("Simulated broken: " + names.joined(separator: ", "))
        }
        lines += overrides.sorted { $0.key.rawValue < $1.key.rawValue }
            .map { "\($0.key.title): \($0.value.label.lowercased())" }
        if let id = deviceOverride {
            lines.append("Pretending to be \(DeviceCatalog.model(for: id)?.name ?? id)")
        }
        return lines
    }

    public func clearAll() {
        broken = []
        overrides = [:]
        deviceOverride = nil
        forceUserConfirmedAudio = false
    }

    /// Replaces the broken components with the scenario's. Keeps the device and audio options.
    public func apply(_ scenario: FaultScenario) {
        broken = scenario.brokenComponents
        overrides = [:]
    }
}
