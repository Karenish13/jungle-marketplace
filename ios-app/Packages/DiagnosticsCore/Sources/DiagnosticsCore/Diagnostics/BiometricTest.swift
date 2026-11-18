import Foundation

/// Face ID or Touch ID: the Local Authentication prompt must succeed.
/// Broken: the app behaves as if iOS reported the biometric hardware unavailable, which is what
/// a phone with a damaged TrueDepth camera or Touch ID sensor shows.
@MainActor
final class BiometricTest: DiagnosticTest {
    let id = TestID.biometrics
    let components: [ComponentID]

    init(components: [ComponentID]) {
        self.components = components
    }

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        guard let component = components.first else { return [] }
        #if os(iOS)
        let name = component.displayName
        let outcome: BiometricOutcome
        if context.faults.isBroken(component) {
            context.show(.working("Starting \(name)…"))
            try await context.sleep(seconds: 1)
            outcome = .unavailable
        } else {
            context.show(.waitingForAction(component == .faceID ? "Look at the phone to use Face ID" : "Put your finger on the home button"))
            outcome = await BiometricCheck.run(reason: "Check that \(name) works")
        }

        return [Self.result(for: outcome, component: component)]
        #else
        return [ComponentResult(component, .notTested, evidence: .automated, note: "Only on an iPhone")]
        #endif
    }
}

extension BiometricTest {
    /// A non-match is "not tested", not a fail: the sensor responded, it just did not know the
    /// person holding the phone (an expo visitor, or a buyer checking a seller's phone).
    static func result(for outcome: BiometricOutcome, component: ComponentID) -> ComponentResult {
        let name = component.displayName
        switch outcome {
        case .success:
            return ComponentResult(component, .pass, evidence: .automated)
        case .noMatch:
            return ComponentResult(component, .notTested, evidence: .automated,
                                   note: "The sensor responded but did not recognise this person")
        case .unavailable:
            return ComponentResult(component, .fail, evidence: .automated,
                                   note: "\(name) is not available (hardware fault, or permission was denied)")
        case .cannotTest(let reason):
            return ComponentResult(component, .notTested, evidence: .automated, note: reason)
        }
    }
}

/// For the screen before the biometric test: a warning when Face ID or Touch ID is not set up,
/// so the user can skip instead of getting a "not tested" result. Nil when it is ready (or on a Mac).
public enum BiometricSetup {
    @MainActor
    public static func warning(for caps: DeviceCapabilities) -> String? {
        #if os(iOS)
        let name = caps.biometric == .faceID ? "Face ID" : "Touch ID"
        var error: NSError?
        if LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) { return nil }
        switch error.flatMap({ LAError.Code(rawValue: $0.code) }) {
        case .biometryNotEnrolled?:
            return "\(name) is not set up on this phone. Set it up in Settings, or skip this test."
        case .passcodeNotSet?:
            return "This phone has no passcode, so iOS will not use \(name). Set a passcode and \(name) in Settings, or skip this test."
        default:
            return nil   // other problems are what the test itself reports
        }
        #else
        return nil
        #endif
    }
}

enum BiometricOutcome: Equatable {
    case success, noMatch, unavailable
    case cannotTest(String)
}

#if os(iOS)
import LocalAuthentication

enum BiometricCheck {
    static func run(reason: String) async -> BiometricOutcome {
        let context = LAContext()
        context.localizedFallbackTitle = ""   // hide "Enter Password"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return outcome(for: error)
        }
        do {
            try await withTaskCancellationHandler {
                _ = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            } onCancel: {
                context.invalidate()
            }
            return .success
        } catch {
            return outcome(for: error as NSError)
        }
    }

    private static func outcome(for error: NSError?) -> BiometricOutcome {
        guard let error, error.domain == LAError.errorDomain else { return .unavailable }
        switch LAError.Code(rawValue: error.code) {
        case .authenticationFailed: return .noMatch
        case .biometryNotEnrolled: return .cannotTest("Not set up in Settings")
        case .passcodeNotSet: return .cannotTest("The phone has no passcode, so iOS will not use biometrics")
        case .biometryLockout: return .cannotTest("Locked out after too many tries; unlock with the passcode and retry")
        case .userCancel, .systemCancel, .appCancel, .userFallback: return .cannotTest("Cancelled")
        default: return .unavailable
        }
    }
}
#endif
