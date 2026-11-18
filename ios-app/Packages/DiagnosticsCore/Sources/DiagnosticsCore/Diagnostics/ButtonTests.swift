import Foundation

/// Watches the system volume for one press up and one press down.
/// Broken: volume changes are ignored, so the presses never register.
@MainActor
final class VolumeButtonsTest: DiagnosticTest {
    let id = TestID.volumeButtons
    let components: [ComponentID] = [.volumeButtons]

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        #if os(iOS)
        let watcher = try VolumeWatcher()
        defer { watcher.stop() }
        let broken = context.faults.isBroken(.volumeButtons)

        // At full volume "up" cannot change anything, so test "down" first.
        let order: [(name: String, up: Bool)] = watcher.volume > 0.95 ? [("down", false), ("up", true)] : [("up", true), ("down", false)]
        var detected: [String] = []
        var missed: [String] = []
        for step in order {
            let baseline = watcher.volume
            let seen = try await context.waitForAction("Press volume \(step.name)", timeout: 20) {
                guard !broken else { return false }
                return step.up ? watcher.volume > baseline + 0.01 : watcher.volume < baseline - 0.01
            }
            if seen { detected.append(step.name) } else { missed.append(step.name) }
        }
        return [ComponentResult(
            .volumeButtons, missed.isEmpty ? .pass : .fail, evidence: .automated,
            measurements: [Measurement("Detected", detected.isEmpty ? "none" : detected.joined(separator: ", "))],
            note: missed.isEmpty ? nil : "Volume \(missed.joined(separator: " and ")) not detected"
        )]
        #else
        return [ComponentResult(.volumeButtons, .notTested, evidence: .automated, note: "Only on an iPhone")]
        #endif
    }
}

/// Side button: the user locks the phone and comes back. The lock is detected from the system's
/// lock notification. If the app left the foreground but no lock signal arrived, the user is
/// asked instead. Broken: the lock signal is ignored and there is no fallback question.
@MainActor
final class SideButtonTest: DiagnosticTest {
    let id = TestID.sideButton
    let components: [ComponentID] = [.sideButton]

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        #if os(iOS)
        let watcher = LifecycleWatcher()
        defer { watcher.stop() }
        let broken = context.faults.isBroken(.sideButton)

        var cameBack = try await context.waitForAction(
            "Press the side button to lock the phone, then unlock it and come back to this app", timeout: 60
        ) { watcher.returned }
        // If the app was suspended past the timeout, give the "became active" event a moment to arrive.
        if !cameBack { cameBack = try await context.waitUntil(timeout: 1) { watcher.returned } }

        if !cameBack || broken {
            return [ComponentResult(.sideButton, .fail, evidence: .automated, note: "Screen lock not detected")]
        }
        if watcher.locked {
            return [ComponentResult(.sideButton, .pass, evidence: .automated, note: "Screen lock detected")]
        }
        let ok = try await context.askYesNo("Did the screen turn off when you pressed the side button?")
        return [ComponentResult(.sideButton, ok ? .pass : .fail, evidence: .userConfirmed,
                                note: ok ? "Lock not detected automatically; user confirmed" : "Screen did not turn off")]
        #else
        return [ComponentResult(.sideButton, .notTested, evidence: .automated, note: "Only on an iPhone")]
        #endif
    }
}

/// Home button (Touch ID phones): pressing it sends the app to the background without a screen
/// lock. Broken: leaving the app is not counted as a press.
@MainActor
final class HomeButtonTest: DiagnosticTest {
    let id = TestID.homeButton
    let components: [ComponentID] = [.homeButton]

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        #if os(iOS)
        let watcher = LifecycleWatcher()
        defer { watcher.stop() }

        var cameBack = try await context.waitForAction(
            "Press the home button, then tap the JUNGLE icon to come back", timeout: 60
        ) { watcher.returned }
        // If the app was suspended past the timeout, give the "became active" event a moment to arrive.
        if !cameBack { cameBack = try await context.waitUntil(timeout: 1) { watcher.returned } }

        if !cameBack || context.faults.isBroken(.homeButton) {
            return [ComponentResult(.homeButton, .fail, evidence: .automated, note: "Home button press not detected")]
        }
        if watcher.locked {
            return [ComponentResult(.homeButton, .notTested, evidence: .automated,
                                    note: "The phone was locked instead; press the home button, not the side button")]
        }
        return [ComponentResult(.homeButton, .pass, evidence: .automated, note: "App left the foreground")]
        #else
        return [ComponentResult(.homeButton, .notTested, evidence: .automated, note: "Only on an iPhone")]
        #endif
    }
}

/// Unplug, then plug in; the battery state must change to charging. The wireless version is the
/// same on a charging pad (iOS cannot tell wired from wireless). Broken: never sees charging.
@MainActor
final class ChargingTest: DiagnosticTest {
    let id: TestID
    let components: [ComponentID]

    init(id: TestID, component: ComponentID) {
        self.id = id
        self.components = [component]
    }

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        guard let component = components.first else { return [] }
        #if os(iOS)
        let battery = BatteryWatcher()
        defer { battery.stop() }
        guard battery.isKnown else {
            return [ComponentResult(component, .notTested, evidence: .automated, note: "Battery state is not available")]
        }
        let broken = context.faults.isBroken(component)
        let wireless = component == .wirelessCharging

        if battery.isCharging {
            let unplugged = try await context.waitForAction(
                wireless ? "Take the phone off the charger" : "Unplug the charging cable", timeout: 30
            ) { !battery.isCharging }
            guard unplugged else {
                return [ComponentResult(component, .notTested, evidence: .automated, note: "Phone was never unplugged")]
            }
        }
        let charging = try await context.waitForAction(
            wireless ? "Unplug any cable and put the phone on a wireless charger" : "Plug in a charging cable", timeout: 30
        ) { !broken && battery.isCharging }

        return [ComponentResult(
            component, charging ? .pass : .fail, evidence: .automated,
            measurements: [Measurement("Battery level", "\(battery.levelPercent)%")]
                + (wireless ? [Measurement("Note", "iOS cannot tell wired from wireless charging")] : []),
            note: charging ? nil : "Charging never started"
        )]
        #else
        return [ComponentResult(component, .notTested, evidence: .automated, note: "Only on an iPhone")]
        #endif
    }
}

/// The user covers the top of the screen; the proximity state must change.
/// Broken: the change is ignored.
@MainActor
final class ProximityTest: DiagnosticTest {
    let id = TestID.proximity
    let components: [ComponentID] = [.proximity]

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        #if os(iOS)
        let device = UIDevice.current
        device.isProximityMonitoringEnabled = true
        defer { device.isProximityMonitoringEnabled = false }
        guard device.isProximityMonitoringEnabled else {
            return [ComponentResult(.proximity, .fail, evidence: .automated, note: "iOS reports no proximity sensor")]
        }
        let broken = context.faults.isBroken(.proximity)
        let covered = try await context.waitForAction("Cover the top of the screen with your hand", timeout: 20) {
            !broken && UIDevice.current.proximityState
        }
        return [ComponentResult(.proximity, covered ? .pass : .fail, evidence: .automated,
                                note: covered ? nil : "Covering the sensor was not detected")]
        #else
        return [ComponentResult(.proximity, .notTested, evidence: .automated, note: "Only on an iPhone")]
        #endif
    }
}

#if os(iOS)
import AVFoundation
import UIKit

/// Observes the system output volume (it changes when a volume button is pressed).
@MainActor
private final class VolumeWatcher {
    private var observation: NSKeyValueObservation?
    private(set) var volume: Float

    init() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient)
        try session.setActive(true)
        volume = session.outputVolume
        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let value = change.newValue else { return }
            DispatchQueue.main.async { self?.volume = value }
        }
    }

    func stop() {
        observation?.invalidate()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Tracks the app leaving and returning to the foreground, and whether the screen was locked.
/// Every callback is delivered on the main queue.
private final class LifecycleWatcher {
    private(set) var wentToBackground = false
    private(set) var returned = false
    fileprivate(set) var locked = false
    private var tokens: [NSObjectProtocol] = []
    private static let lockNotification = "com.apple.springboard.lockcomplete" as CFString

    init() {
        let center = NotificationCenter.default
        tokens.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.wentToBackground = true
        })
        tokens.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            if self?.wentToBackground == true { self?.returned = true }
        })
        // Only fires when a passcode is set, so it is a backup for the Darwin notification below.
        tokens.append(center.addObserver(forName: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil, queue: .main) { [weak self] _ in
            self?.locked = true
        })
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let watcher = Unmanaged<LifecycleWatcher>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { watcher.locked = true }
            },
            Self.lockNotification, nil, .deliverImmediately
        )
    }

    func stop() {
        tokens.forEach(NotificationCenter.default.removeObserver)
        tokens = []
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                           Unmanaged.passUnretained(self).toOpaque(),
                                           CFNotificationName(Self.lockNotification), nil)
    }
}

/// Battery state, polled from UIDevice.
@MainActor
private final class BatteryWatcher {
    init() { UIDevice.current.isBatteryMonitoringEnabled = true }

    var isKnown: Bool { UIDevice.current.batteryState != .unknown }
    var isCharging: Bool { [.charging, .full].contains(UIDevice.current.batteryState) }
    var levelPercent: Int { Int((UIDevice.current.batteryLevel * 100).rounded()) }

    func stop() { UIDevice.current.isBatteryMonitoringEnabled = false }
}
#endif
