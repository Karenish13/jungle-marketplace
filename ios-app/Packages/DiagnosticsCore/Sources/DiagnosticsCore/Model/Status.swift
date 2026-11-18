import Foundation

/// The outcome for one component, or for a whole test.
public enum TestStatus: String, Codable, CaseIterable, Sendable {
    case pass
    case fail
    /// Skipped, timed out without an answer, or not built yet.
    case notTested
    /// This model does not have the component (e.g. LiDAR on an iPhone 7).
    case notPresent

    public var label: String {
        switch self {
        case .pass: return "Pass"
        case .fail: return "Fail"
        case .notTested: return "Not tested"
        case .notPresent: return "Not present"
        }
    }
}

/// How much a result can be trusted. Shown next to every result in the report.
public enum Evidence: String, Codable, CaseIterable, Sendable {
    /// The app measured the result itself.
    case automated
    /// The app ran the stimulus and the user said whether it worked.
    case userConfirmed
    /// The user typed or chose it in the survey; the app cannot check it.
    case selfReported

    public var label: String {
        switch self {
        case .automated: return "Automated"
        case .userConfirmed: return "User-confirmed"
        case .selfReported: return "Self-reported"
        }
    }
}

/// A developer override on a whole test.
public enum ResultOverride: String, Codable, CaseIterable, Sendable {
    case real
    case forceFail
    case forceNotTested

    public var label: String {
        switch self {
        case .real: return "Real"
        case .forceFail: return "Force fail"
        case .forceNotTested: return "Force not tested"
        }
    }
}
