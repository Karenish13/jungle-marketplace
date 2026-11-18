import Foundation

/// A 3-axis reading.
public struct Vector3: Equatable, Sendable {
    public var x, y, z: Double
    public init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
}

/// Pass/fail rules for the motion sensors, kept separate so they can be unit tested.
public enum MotionVerdict {
    /// Largest change on any one axis across the readings.
    static func largestAxisRange(_ readings: [Vector3]) -> Double {
        guard !readings.isEmpty else { return 0 }
        let axes: [(Vector3) -> Double] = [{ $0.x }, { $0.y }, { $0.z }]
        return axes.map { axis in
            let values = readings.map(axis)
            return values.max()! - values.min()!
        }.max()!
    }

    /// Tilting moves gravity between axes, so at least one axis must change by 0.3 g.
    public static func accelerometer(_ readings: [Vector3]) -> (TestStatus, String?) {
        if readings.isEmpty { return (.fail, "No readings") }
        return largestAxisRange(readings) >= 0.3 ? (.pass, nil) : (.fail, "Readings barely changed while the phone moved")
    }

    /// Turning the phone must produce at least 0.5 rad/s on some axis.
    public static func gyroscope(_ readings: [Vector3]) -> (TestStatus, String?) {
        if readings.isEmpty { return (.fail, "No readings") }
        let peak = readings.map { max(abs($0.x), abs($0.y), abs($0.z)) }.max()!
        return peak >= 0.5 ? (.pass, nil) : (.fail, "No rotation detected")
    }

    /// Turning the phone swings Earth's field between axes: at least 10 µT on some axis.
    public static func compass(_ readings: [Vector3]) -> (TestStatus, String?) {
        if readings.isEmpty { return (.fail, "No readings") }
        return largestAxisRange(readings) >= 10 ? (.pass, nil) : (.fail, "Magnetic field never changed")
    }

    /// Air pressure only needs to be plausible (kPa); it does not change when you tilt a phone.
    public static func barometer(_ pressures: [Double]) -> (TestStatus, String?) {
        guard let last = pressures.last else { return (.fail, "No readings") }
        return (30...110).contains(last) ? (.pass, nil) : (.fail, String(format: "Implausible pressure: %.1f kPa", last))
    }
}

/// Records the accelerometer, gyroscope, magnetometer and barometer while the user moves the
/// phone. Broken sensor: its readings are thrown away, as if the sensor sent nothing.
@MainActor
final class MotionTest: DiagnosticTest {
    let id = TestID.motionSensors
    let components: [ComponentID]
    private let duration = 6.0

    init(components: [ComponentID]) {
        self.components = components
    }

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        #if os(iOS)
        // The barometer needs Motion & Fitness permission. Ask before the timed window starts,
        // or the user reads the prompt instead of moving the phone.
        if components.contains(.barometer), MotionPermissionRequest.isNeeded {
            let request = MotionPermissionRequest()
            request.start()
            defer { request.stop() }
            context.show(.working("Allow Motion & Fitness access to test the barometer…"))
            _ = try await context.waitUntil(timeout: 60) { !MotionPermissionRequest.isNeeded }
        }

        let recorder = MotionRecorder()
        let availability = recorder.start(barometer: components.contains(.barometer))
        defer { recorder.stop() }

        try await context.countdown("Tilt the phone and turn it around slowly…", seconds: duration)

        let faults = context.faults
        func readings(_ c: ComponentID, _ values: [Vector3]) -> [Vector3] { faults.isBroken(c) ? [] : values }

        var results: [ComponentResult] = []
        func add(_ c: ComponentID, available: Bool, count: Int, _ verdict: (TestStatus, String?), _ extra: [Measurement] = []) {
            if !available {
                results.append(ComponentResult(c, .fail, evidence: .automated, note: "iOS reports no \(c.displayName.lowercased())"))
            } else {
                results.append(ComponentResult(c, verdict.0, evidence: .automated,
                                               measurements: [Measurement("Readings", "\(count)")] + extra, note: verdict.1))
            }
        }

        let accel = readings(.accelerometer, recorder.accelerometer)
        add(.accelerometer, available: availability.accelerometer, count: accel.count, MotionVerdict.accelerometer(accel),
            [Measurement("Largest change", String(format: "%.2f g", MotionVerdict.largestAxisRange(accel)))])
        let gyro = readings(.gyroscope, recorder.gyroscope)
        add(.gyroscope, available: availability.gyroscope, count: gyro.count, MotionVerdict.gyroscope(gyro))
        let mag = readings(.compass, recorder.magnetometer)
        add(.compass, available: availability.magnetometer, count: mag.count, MotionVerdict.compass(mag),
            [Measurement("Largest change", String(format: "%.0f µT", MotionVerdict.largestAxisRange(mag)))])

        if components.contains(.barometer) {
            if let denied = recorder.barometerError {
                results.append(ComponentResult(.barometer, .notTested, evidence: .automated, note: denied))
            } else {
                let pressures = faults.isBroken(.barometer) ? [] : recorder.pressures
                add(.barometer, available: availability.barometer, count: pressures.count, MotionVerdict.barometer(pressures),
                    pressures.last.map { [Measurement("Pressure", String(format: "%.1f kPa", $0))] } ?? [])
            }
        }
        return results
        #else
        return components.map { ComponentResult($0, .notTested, evidence: .automated, note: "Only on an iPhone") }
        #endif
    }
}

#if os(iOS)
import CoreMotion

/// Collects raw sensor readings on the main queue.
@MainActor
private final class MotionRecorder {
    private let manager = CMMotionManager()
    private let altimeter = CMAltimeter()
    private(set) var accelerometer: [Vector3] = []
    private(set) var gyroscope: [Vector3] = []
    private(set) var magnetometer: [Vector3] = []
    private(set) var pressures: [Double] = []
    private(set) var barometerError: String?

    func start(barometer: Bool) -> (accelerometer: Bool, gyroscope: Bool, magnetometer: Bool, barometer: Bool) {
        let interval = 1.0 / 50
        manager.accelerometerUpdateInterval = interval
        manager.gyroUpdateInterval = interval
        manager.magnetometerUpdateInterval = interval
        if manager.isAccelerometerAvailable {
            manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let a = data?.acceleration else { return }
                self?.accelerometer.append(Vector3(a.x, a.y, a.z))
            }
        }
        if manager.isGyroAvailable {
            manager.startGyroUpdates(to: .main) { [weak self] data, _ in
                guard let r = data?.rotationRate else { return }
                self?.gyroscope.append(Vector3(r.x, r.y, r.z))
            }
        }
        if manager.isMagnetometerAvailable {
            manager.startMagnetometerUpdates(to: .main) { [weak self] data, _ in
                guard let f = data?.magneticField else { return }
                self?.magnetometer.append(Vector3(f.x, f.y, f.z))
            }
        }
        let hasBarometer = barometer && CMAltimeter.isRelativeAltitudeAvailable()
        if hasBarometer {
            if CMAltimeter.authorizationStatus() == .denied || CMAltimeter.authorizationStatus() == .restricted {
                barometerError = "Motion & Fitness permission was denied"
            } else {
                altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
                    if let pressure = data?.pressure.doubleValue { self?.pressures.append(pressure) }
                    if error != nil, self?.pressures.isEmpty == true {
                        self?.barometerError = "Motion & Fitness permission was denied"
                    }
                }
            }
        }
        return (manager.isAccelerometerAvailable, manager.isGyroAvailable, manager.isMagnetometerAvailable, hasBarometer)
    }

    func stop() {
        manager.stopAccelerometerUpdates()
        manager.stopGyroUpdates()
        manager.stopMagnetometerUpdates()
        altimeter.stopRelativeAltitudeUpdates()
    }
}
#endif
