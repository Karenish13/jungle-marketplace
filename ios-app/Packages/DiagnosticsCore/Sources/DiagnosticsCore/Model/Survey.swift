import Foundation

/// The four areas the seller grades.
public enum CosmeticArea: String, Codable, CaseIterable, Sendable {
    case screen, back, sides, cameraGlass

    public var title: String {
        switch self {
        case .screen: return "Screen"
        case .back: return "Back"
        case .sides: return "Sides"
        case .cameraGlass: return "Camera glass"
        }
    }

    public var covers: String {
        switch self {
        case .screen: return "Front glass"
        case .back: return "Back glass or back material"
        case .sides: return "Frame / side case"
        case .cameraGlass: return "Rear lens covers"
        }
    }
}

/// Ordered best to worst, so `max()` gives the worst rating.
public enum CosmeticRating: String, Codable, CaseIterable, Comparable, Sendable {
    case excellent, good, fair, poor

    public var title: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }

    /// Shown under every question so sellers grade consistently.
    public var definition: String {
        switch self {
        case .excellent: return "No visible scratches, cracks or dents"
        case .good: return "Light scratches only, hard to see at arm's length"
        case .fair: return "Obvious scratches, scuffs or small dents; no cracks"
        case .poor: return "Cracks, chips, deep dents or missing material"
        }
    }

    private var rank: Int { Self.allCases.firstIndex(of: self)! }

    public static func < (lhs: CosmeticRating, rhs: CosmeticRating) -> Bool { lhs.rank < rhs.rank }
}

public enum YesNoUnsure: String, Codable, CaseIterable, Sendable {
    case yes, no, unsure

    public var title: String {
        switch self {
        case .yes: return "Yes"
        case .no: return "No"
        case .unsure: return "Not sure"
        }
    }
}

/// Everything the seller enters after the diagnostics. Optional fields are unanswered.
public struct SurveyAnswers: Codable, Hashable, Sendable {
    // Cosmetic condition
    public var screen: CosmeticRating?
    public var back: CosmeticRating?
    public var sides: CosmeticRating?
    public var cameraGlass: CosmeticRating?

    // Declarations
    /// From Settings > Battery > Battery Health. No public API can read it.
    /// Kept within 0...100.
    public var batteryHealthPercent: Int? {
        didSet { if let v = batteryHealthPercent, !(0...100).contains(v) { batteryHealthPercent = min(max(v, 0), 100) } }
    }
    public var partsReplaced: YesNoUnsure?
    public var activationLockOff: Bool?
    /// Optional. Shown in the report so a buyer can match it to the phone received.
    public var imei: String?

    /// The one free-text box.
    public var notes: String

    public init(
        screen: CosmeticRating? = nil,
        back: CosmeticRating? = nil,
        sides: CosmeticRating? = nil,
        cameraGlass: CosmeticRating? = nil,
        batteryHealthPercent: Int? = nil,
        partsReplaced: YesNoUnsure? = nil,
        activationLockOff: Bool? = nil,
        imei: String? = nil,
        notes: String = ""
    ) {
        self.screen = screen
        self.back = back
        self.sides = sides
        self.cameraGlass = cameraGlass
        self.batteryHealthPercent = batteryHealthPercent.map { min(max($0, 0), 100) }
        self.partsReplaced = partsReplaced
        self.activationLockOff = activationLockOff
        self.imei = imei
        self.notes = notes
    }

    /// Read or write a cosmetic rating by area, so a UI can loop over `CosmeticArea.allCases`.
    public subscript(area: CosmeticArea) -> CosmeticRating? {
        get {
            switch area {
            case .screen: return screen
            case .back: return back
            case .sides: return sides
            case .cameraGlass: return cameraGlass
            }
        }
        set {
            switch area {
            case .screen: screen = newValue
            case .back: back = newValue
            case .sides: sides = newValue
            case .cameraGlass: cameraGlass = newValue
            }
        }
    }

    /// Worst of the four areas, or nil until all four are answered.
    public var cosmeticGrade: CosmeticRating? {
        let ratings = CosmeticArea.allCases.compactMap { self[$0] }
        guard ratings.count == CosmeticArea.allCases.count else { return nil }
        return ratings.max()
    }

    /// Questions still unanswered. IMEI and notes are optional and never listed.
    public var missing: [String] {
        var result = CosmeticArea.allCases.filter { self[$0] == nil }.map(\.title)
        if batteryHealthPercent == nil { result.append("Battery health") }
        if partsReplaced == nil { result.append("Replaced parts") }
        if activationLockOff == nil { result.append("Activation Lock") }
        return result
    }

    public var isComplete: Bool { missing.isEmpty }

    /// Battery is self-reported. Below 80% is where Apple recommends service.
    public var batteryResult: ComponentResult {
        guard let health = batteryHealthPercent else {
            return ComponentResult(.battery, .notTested, evidence: .selfReported, note: "Battery health not entered")
        }
        return ComponentResult(
            .battery,
            health >= 80 ? .pass : .fail,
            evidence: .selfReported,
            measurements: [Measurement("Battery health", "\(health)%")],
            note: health >= 80 ? nil : "Below 80%, Apple recommends service"
        )
    }
}

/// Observable wrapper the survey screens bind to, e.g. `Picker(selection: $survey.answers.screen)`.
@MainActor
public final class SurveyModel: ObservableObject {
    @Published public var answers: SurveyAnswers

    public init(answers: SurveyAnswers = SurveyAnswers()) {
        self.answers = answers
    }

    public func reset() { answers = SurveyAnswers() }

    /// For the test bench and previews.
    public func fillWithSampleData() { answers = .sampleHealthy }
}

public extension SurveyAnswers {
    static let sampleHealthy = SurveyAnswers(
        screen: .excellent, back: .good, sides: .good, cameraGlass: .excellent,
        batteryHealthPercent: 89, partsReplaced: .no, activationLockOff: true,
        imei: "356938035643809", notes: "Always kept in a case."
    )

    static let samplePartsDonor = SurveyAnswers(
        screen: .poor, back: .fair, sides: .fair, cameraGlass: .good,
        batteryHealthPercent: 71, partsReplaced: .unsure, activationLockOff: true,
        imei: nil, notes: "Dropped. Screen cracked in the bottom corner."
    )
}
