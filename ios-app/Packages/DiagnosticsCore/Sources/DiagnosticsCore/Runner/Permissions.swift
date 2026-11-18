import Foundation

/// Asks for every permission the tests need, before any test starts, so no system prompt
/// appears in the middle of a timed measurement. Call it from the onboarding screen and the
/// test bench. Each prompt is shown one after another; a permission already answered is skipped.
/// The tests still handle a denied or unanswered permission themselves.
@MainActor
public enum Permissions {
    /// Camera, microphone, Motion & Fitness, Bluetooth and location. Returns when every prompt
    /// has been answered (or after a minute per prompt). Does nothing on a Mac.
    public static func requestAll() async {
        #if os(iOS)
        _ = await CameraSession.requestAccess()
        _ = await AudioRig.requestMicAccess()

        if MotionPermissionRequest.isNeeded {
            let request = MotionPermissionRequest()
            request.start()
            await poll { !MotionPermissionRequest.isNeeded }
            request.stop()
        }
        if CBManager.authorization == .notDetermined {
            // Creating a manager shows the prompt; keep it alive until it is answered.
            let manager = CBCentralManager(delegate: nil, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: false])
            await poll { CBManager.authorization != .notDetermined }
            _ = manager
        }
        // With Location Services off for the whole phone the prompt never appears, so don't wait for it.
        let servicesOn = await Task.detached { CLLocationManager.locationServicesEnabled() }.value
        let location = CLLocationManager()
        if servicesOn, location.authorizationStatus == .notDetermined {
            location.requestWhenInUseAuthorization()
            await poll { location.authorizationStatus != .notDetermined }
        }
        #endif
    }

    private static func poll(timeout: Double = 60, _ done: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !done(), Date() < deadline, !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
}

#if os(iOS)
import CoreBluetooth
import CoreLocation
import CoreMotion

/// Triggers the Motion & Fitness prompt (used by the barometer) without starting a measurement.
@MainActor
final class MotionPermissionRequest {
    static var isNeeded: Bool {
        CMAltimeter.authorizationStatus() == .notDetermined
            && (CMMotionActivityManager.isActivityAvailable() || CMAltimeter.isRelativeAltitudeAvailable())
    }

    private let activity = CMMotionActivityManager()
    private let altimeter = CMAltimeter()

    func start() {
        if CMMotionActivityManager.isActivityAvailable() {
            activity.queryActivityStarting(from: Date(), to: Date(), to: .main) { _, _ in }
        } else {
            altimeter.startRelativeAltitudeUpdates(to: .main) { _, _ in }
        }
    }

    func stop() { altimeter.stopRelativeAltitudeUpdates() }
}
#endif
