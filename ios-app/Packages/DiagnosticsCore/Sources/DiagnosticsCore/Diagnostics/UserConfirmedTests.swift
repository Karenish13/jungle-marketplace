import Foundation
#if os(iOS)
import AudioToolbox
import UIKit
#endif

/// Solid colour screens, then the user says whether they looked right.
/// Broken: a stuck column of pixels is drawn on every colour.
@MainActor
final class DisplayTest: DiagnosticTest {
    let id = TestID.display
    let components: [ComponentID] = [.display]

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        let defect: DisplayDefect? = context.faults.isBroken(.display) ? .deadColumn : nil
        try await context.present(.colourScreens(DisplayColour.allCases, defect: defect))
        let ok = try await context.askYesNo(
            "Did every colour look even, with no dead pixels, lines, burn-in, tint or bright patches at the edges?"
        )
        return [ComponentResult(.display, ok ? .pass : .fail, evidence: .userConfirmed,
                                note: ok ? nil : "User saw a display problem")]
    }
}

/// Plays a few vibrations, then asks. Broken: nothing vibrates.
@MainActor
final class HapticsTest: DiagnosticTest {
    let id = TestID.haptics
    let components: [ComponentID] = [.haptics]

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        context.show(.working("Feel for vibrations…"))
        try await context.sleep(seconds: 0.5)
        let broken = context.faults.isBroken(.haptics)
        for _ in 0..<3 {
            if !broken { Self.pulse() }
            try await context.sleep(seconds: 0.6)
        }
        if !broken { Self.longVibrate() }
        try await context.sleep(seconds: 0.6)

        let ok = try await context.askYesNo("Did you feel the phone vibrate?")
        return [ComponentResult(.haptics, ok ? .pass : .fail, evidence: .userConfirmed,
                                note: ok ? nil : "No vibration felt")]
    }

    /// UIKit feedback generators, because Core Haptics does not support the iPhone 7.
    private static func pulse() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    /// The classic vibration, which also works on phones without a Taptic Engine (6s, SE 1st gen).
    private static func longVibrate() {
        #if os(iOS)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        #endif
    }
}

/// No public API reads the mute switch or Action button, so the user confirms iOS's own indicator.
/// Broken: the app cannot block the system indicator, so it treats the toggle as never seen
/// and ignores a "yes" (the note says so).
@MainActor
final class RingerControlTest: DiagnosticTest {
    let id = TestID.ringerControl
    let components: [ComponentID]

    init(components: [ComponentID]) {
        self.components = components
    }

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        guard let control = components.first else { return [] }
        let question = control == .muteSwitch
            ? "Flip the mute switch on the side of the phone, then flip it back. Did the Silent Mode indicator appear at the top of the screen?"
            : "Press and hold the Action button. Did it do its action (for example Silent Mode or the flashlight)?"
        let answer = try await context.askYesNo(question)
        if context.faults.isBroken(control) {
            return [ComponentResult(control, .fail, evidence: .userConfirmed,
                                    note: "Simulated fault: toggle treated as not seen")]
        }
        return [ComponentResult(control, answer ? .pass : .fail, evidence: .userConfirmed,
                                note: answer ? nil : "User did not see it respond")]
    }
}
