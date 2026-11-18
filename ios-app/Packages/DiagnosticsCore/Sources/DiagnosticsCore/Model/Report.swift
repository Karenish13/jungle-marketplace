import Foundation

/// A finished condition report. Saved as JSON (this type) next to the rendered PDF.
/// Bump `currentSchemaVersion` when a stored field changes meaning or is removed.
public struct Report: Codable, Hashable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    /// Short code printed on every page, e.g. "JGL-7K3Q-9PXM".
    public var id: String
    public var createdAt: Date
    public var appVersion: String
    public var device: DeviceProfile
    /// One entry per test that ran, in plan order.
    public var results: [TestResult]
    public var survey: SurveyAnswers
    /// Non-nil when any developer option was active. The PDF stamps
    /// "Demo: simulated results" on every page when this is set; it cannot be turned off.
    public var simulation: SimulationStamp?

    public init(
        id: String = Report.newID(),
        createdAt: Date = Date(),
        appVersion: String,
        device: DeviceProfile,
        results: [TestResult],
        survey: SurveyAnswers,
        simulation: SimulationStamp?
    ) {
        self.schemaVersion = Report.currentSchemaVersion
        self.id = id
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.device = device
        self.results = results
        self.survey = survey
        self.simulation = simulation
    }

    public var isSimulated: Bool { simulation != nil }

    /// The stamp combines what was active while each test ran, a pretend device, and whatever is
    /// active now, so turning the options off after a run does not remove it.
    @MainActor
    public static func make(device: DeviceProfile, results: [TestResult], survey: SurveyAnswers,
                            faults: FaultInjector, appVersion: String) -> Report {
        var details: [String] = results.flatMap { $0.simulation ?? [] }
        if device.actualModelIdentifier != nil { details.append("Pretending to be \(device.modelName)") }
        if faults.isActive { details += faults.activeDescriptions }
        var seen = Set<String>()
        details = details.filter { seen.insert($0).inserted }
        let simulation = details.isEmpty ? nil : SimulationStamp(details: details)
        return Report(appVersion: appVersion, device: device, results: results, survey: survey, simulation: simulation)
    }

    public static var bundleAppVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    /// Unambiguous characters only (no 0/O, 1/I/L).
    public static func newID() -> String {
        let chars = Array("23456789ABCDEFGHJKMNPQRSTUVWXYZ")
        let block = { String((0..<4).map { _ in chars.randomElement()! }) }
        return "JGL-\(block())-\(block())"
    }
}

public struct SimulationStamp: Codable, Hashable, Sendable {
    public static let label = "Demo: simulated results"
    /// Which options were active, e.g. "Touch dead zone".
    public var details: [String]
}

// MARK: - Derived views used by the summary screen and the PDF

public struct ComponentRow: Hashable, Identifiable, Sendable {
    public var component: ComponentID
    public var status: TestStatus
    /// Nil for "not present".
    public var evidence: Evidence?
    public var note: String?
    public var measurements: [Measurement]

    public var id: ComponentID { component }
}

public struct PartGroup: Hashable, Identifiable, Sendable {
    public var part: ReplaceablePart
    public var rows: [ComponentRow]

    public var id: ReplaceablePart { part }

    /// Fail if any component failed, pass if every component passed, otherwise not tested.
    public var status: TestStatus {
        if rows.contains(where: { $0.status == .fail }) { return .fail }
        if rows.allSatisfy({ $0.status == .pass }) { return .pass }
        return .notTested
    }

    /// Every component in the part was tested and passed: safe to buy as a donor part.
    public var isHarvestable: Bool { status == .pass }

    /// A caveat to show next to the part in the parts view and the PDF, or nil.
    public var transferNote: String? {
        let components = Set(rows.map(\.component))
        if components.contains(.touchID) {
            return "Paired to the original phone: Touch ID will not work after transfer. The button still clicks."
        }
        if components.contains(.faceID) {
            return "Paired to the original phone: Face ID will not work after transfer. The camera still works."
        }
        return nil
    }
}

public enum FunctionalGrade: String, Codable, Sendable {
    /// No failures, and every tier 1 component this phone has was tested.
    case allWorking
    /// No failures, but at least one tier 1 component was not tested (skipped, quick demo, etc.).
    case incomplete
    case minorFaults, forParts

    public var title: String {
        switch self {
        case .allWorking: return "All tested components working"
        case .incomplete: return "No faults found, but not fully tested"
        case .minorFaults: return "Working, with faults"
        case .forParts: return "For parts or repair"
        }
    }
}

public extension Report {
    /// Components whose failure makes the phone "for parts".
    static let criticalComponents: Set<ComponentID> = [.touchscreen, .display, .chargingPort]

    /// Every component in the catalog: its result if tested, "not present" if this model lacks it,
    /// otherwise "not tested". Battery comes from the survey.
    var componentRows: [ComponentRow] {
        var latest: [ComponentID: ComponentResult] = [:]
        for result in results {
            for c in result.components { latest[c.component] = c }
        }
        latest[.battery] = survey.batteryResult

        return ComponentID.allCases.map { component in
            if let r = latest[component] {
                return ComponentRow(component: component, status: r.status, evidence: r.evidence,
                                    note: r.note, measurements: r.measurements)
            }
            if !device.capabilities.has(component) {
                return ComponentRow(component: component, status: .notPresent, evidence: nil, note: nil, measurements: [])
            }
            return ComponentRow(component: component, status: .notTested, evidence: nil, note: nil, measurements: [])
        }
    }

    /// The component table for the summary screen and the PDF: only what this model has, so
    /// for example wireless charging, LiDAR or 3D Touch never appear on a phone without them.
    var presentComponentRows: [ComponentRow] {
        componentRows.filter { $0.status != .notPresent }
    }

    /// The parts view: present components grouped by replaceable part.
    var partGroups: [PartGroup] {
        let rows = presentComponentRows
        return ReplaceablePart.allCases.compactMap { part in
            let partRows = rows.filter { $0.component.part == part }
            return partRows.isEmpty ? nil : PartGroup(part: part, rows: partRows)
        }
    }

    var functionalGrade: FunctionalGrade {
        let rows = componentRows
        let failed = rows.filter { $0.status == .fail }.map(\.component)
        if !failed.isEmpty {
            return failed.contains(where: Self.criticalComponents.contains) ? .forParts : .minorFaults
        }
        let tier1 = Set(TestID.allCases.filter { $0.tier == 1 }.flatMap { $0.components(for: device.capabilities) })
        let untested = rows.contains { $0.status == .notTested && tier1.contains($0.component) }
        return untested ? .incomplete : .allWorking
    }

    /// Worst of the four cosmetic areas, or nil if the survey was not finished.
    var cosmeticGrade: CosmeticRating? { survey.cosmeticGrade }

    var counts: (pass: Int, fail: Int, notTested: Int) {
        let rows = componentRows
        return (rows.filter { $0.status == .pass }.count,
                rows.filter { $0.status == .fail }.count,
                rows.filter { $0.status == .notTested }.count)
    }
}

// MARK: - JSON

public extension Report {
    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func jsonData() throws -> Data { try Report.encoder().encode(self) }

    static func fromJSON(_ data: Data) throws -> Report { try decoder().decode(Report.self, from: data) }
}
