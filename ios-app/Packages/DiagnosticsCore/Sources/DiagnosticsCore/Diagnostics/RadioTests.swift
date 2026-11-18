import Foundation

/// Wi-Fi or cellular: is the interface connected, and does a request over it get through?
/// Being connected shows the radio works, so a network with no internet access is "not tested",
/// not a fail; so is no network or no SIM. Broken: behaves as if iOS found no radio at all.
/// (A real dead radio usually just shows as not connected; the app cannot tell that from a
/// phone with Wi-Fi turned off.)
@MainActor
final class NetworkTest: DiagnosticTest {
    let id: TestID
    let components: [ComponentID]

    init(id: TestID, component: ComponentID) {
        self.id = id
        self.components = [component]
    }

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        guard let component = components.first else { return [] }
        #if os(iOS)
        let wifi = component == .wifi
        context.show(.working(wifi ? "Checking Wi-Fi…" : "Checking cellular data…"))
        let interface: NetworkProbe.Interface = wifi ? .wifi : .cellular

        if context.faults.isBroken(component) {
            try await context.sleep(seconds: 2)
            return [ComponentResult(component, .fail, evidence: .automated,
                                    note: wifi ? "Wi-Fi hardware not responding" : "Cellular hardware not responding")]
        }
        guard await NetworkProbe.isConnected(interface) else {
            return [ComponentResult(component, .notTested, evidence: .automated,
                                    note: wifi ? "Not connected to a Wi-Fi network" : "No SIM or cellular data")]
        }
        let started = Date()
        let reached = await NetworkProbe.canReachInternet(over: interface)
        let ms = Int(Date().timeIntervalSince(started) * 1000)
        if reached {
            return [ComponentResult(component, .pass, evidence: .automated,
                                    measurements: [Measurement("Response time", "\(ms) ms")])]
        }
        return [ComponentResult(component, .notTested, evidence: .automated,
                                note: "Connected, but the network has no internet access")]
        #else
        return [ComponentResult(component, .notTested, evidence: .automated, note: "Only on an iPhone")]
        #endif
    }
}

/// Scans for nearby Bluetooth LE devices. Broken: behaves as if the Bluetooth chip is missing.
@MainActor
final class BluetoothTest: DiagnosticTest {
    let id = TestID.bluetooth
    let components: [ComponentID] = [.bluetooth]

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        #if os(iOS)
        // Creating the scanner shows the Bluetooth permission prompt on first use, so give the
        // user time to answer it before treating "never started" as a fault.
        let asking = BluetoothScanner.needsPermission
        let scanner = BluetoothScanner()
        defer { scanner.stop() }
        context.show(.working(asking ? "Allow Bluetooth access to test Bluetooth…" : "Turning on Bluetooth…"))
        _ = try await context.waitUntil(timeout: asking ? 60 : 10) { scanner.state != .unknown && scanner.state != .resetting }
        let state: BluetoothScanner.State = context.faults.isBroken(.bluetooth) ? .unsupported : scanner.state

        switch state {
        case .poweredOn:
            scanner.scan()
            try await context.countdown("Looking for nearby Bluetooth devices…", seconds: 6)
            let found = scanner.found.count
            if found == 0 {
                return [ComponentResult(.bluetooth, .notTested, evidence: .automated, note: "No Bluetooth devices nearby to detect")]
            }
            return [ComponentResult(.bluetooth, .pass, evidence: .automated, measurements: [Measurement("Devices found", "\(found)")])]
        case .poweredOff:
            return [ComponentResult(.bluetooth, .notTested, evidence: .automated, note: "Bluetooth is turned off")]
        case .unauthorized:
            return [ComponentResult(.bluetooth, .notTested, evidence: .automated, note: "Bluetooth permission was denied")]
        case .unsupported:
            return [ComponentResult(.bluetooth, .fail, evidence: .automated, note: "Bluetooth hardware not responding")]
        case .unknown, .resetting:
            return [ComponentResult(.bluetooth, .fail, evidence: .automated, note: "Bluetooth never started")]
        }
        #else
        return [ComponentResult(.bluetooth, .notTested, evidence: .automated, note: "Only on an iPhone")]
        #endif
    }
}

/// Gets a location fix. Note: iOS may use Wi-Fi positioning, so this proves location works
/// rather than the GPS chip alone. No fix in time is "not tested" (common indoors).
/// Broken: location updates are ignored and the hardware is reported as not responding.
@MainActor
final class GPSTest: DiagnosticTest {
    let id = TestID.gps
    let components: [ComponentID] = [.gps]
    static let requiredAccuracy = 100.0   // metres

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        #if os(iOS)
        func notTested(_ note: String) -> [ComponentResult] {
            [ComponentResult(.gps, .notTested, evidence: .automated, note: note)]
        }
        // With Location Services off for the whole phone, iOS never shows the permission prompt.
        context.show(.working("Checking location access…"))
        guard await Locator.servicesEnabled() else {
            return notTested("Location Services is turned off in Settings > Privacy & Security > Location Services")
        }
        let locator = Locator()
        defer { locator.stop() }
        if locator.needsPermission {
            context.show(.working("Tap \"Allow While Using App\" when iOS asks for your location…"))
            locator.requestPermission()
            guard try await context.waitUntil(timeout: 60, { !locator.needsPermission }) else {
                return notTested("The location permission prompt was not answered")
            }
        }
        switch locator.access {
        case .allowed: break
        case .denied: return notTested("Location access is off for this app. Turn it on in Settings > JUNGLE > Location")
        case .restricted: return notTested("Location is restricted on this phone (Screen Time or a management profile)")
        case .undecided: return notTested("The location permission prompt was not answered")
        }
        // Approximate location is accurate only to a few kilometres, so it cannot show GPS works.
        if locator.isApproximate {
            return notTested("Precise Location is off for this app. Turn it on in Settings > JUNGLE > Location")
        }

        locator.start()
        let broken = context.faults.isBroken(.gps)
        context.show(.working("Finding your location…"))
        let fixed = try await context.waitUntil(timeout: 20) {
            !broken && (locator.bestAccuracy ?? .infinity) <= Self.requiredAccuracy
        }
        if broken {
            return [ComponentResult(.gps, .fail, evidence: .automated, note: "Location hardware not responding")]
        }
        return [ComponentResult(
            .gps, fixed ? .pass : .notTested, evidence: .automated,
            measurements: locator.bestAccuracy.map { [Measurement("Accuracy", String(format: "%.0f m", $0))] } ?? [],
            note: fixed ? nil : "No accurate location within 20 seconds; try near a window or outside"
        )]
        #else
        return [ComponentResult(.gps, .notTested, evidence: .automated, note: "Only on an iPhone")]
        #endif
    }
}

#if os(iOS)
import CoreBluetooth
import CoreLocation
import Network

enum NetworkProbe {
    enum Interface { case wifi, cellular }

    private static func type(_ interface: Interface) -> NWInterface.InterfaceType {
        interface == .wifi ? .wifi : .cellular
    }

    /// Whether the interface currently has a usable path.
    static func isConnected(_ interface: Interface, timeout: Double = 3) async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor(requiredInterfaceType: type(interface))
            let once = Once()
            let queue = DispatchQueue(label: "jungle.path")
            monitor.pathUpdateHandler = { path in
                once.run { continuation.resume(returning: path.status == .satisfied) }
                monitor.cancel()
            }
            monitor.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                once.run { continuation.resume(returning: false) }
                monitor.cancel()
            }
        }
    }

    /// Opens a TCP connection to Apple's captive-portal host, forced over the interface.
    static func canReachInternet(over interface: Interface, timeout: Double = 8) async -> Bool {
        await withCheckedContinuation { continuation in
            let parameters = NWParameters.tcp
            parameters.requiredInterfaceType = type(interface)
            let connection = NWConnection(host: "captive.apple.com", port: 80, using: parameters)
            let once = Once()
            let queue = DispatchQueue(label: "jungle.connect")
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: once.run { continuation.resume(returning: true) }; connection.cancel()
                case .failed: once.run { continuation.resume(returning: false) }; connection.cancel()
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                once.run { continuation.resume(returning: false) }
                connection.cancel()
            }
        }
    }
}

/// Runs a block at most once, from any thread.
final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func run(_ block: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        block()
    }
}

private final class BluetoothScanner: NSObject, CBCentralManagerDelegate {
    enum State { case unknown, resetting, unsupported, unauthorized, poweredOff, poweredOn }

    static var needsPermission: Bool { CBManager.authorization == .notDetermined }

    private var manager: CBCentralManager!
    private(set) var state: State = .unknown
    private(set) var found: Set<UUID> = []

    override init() {
        super.init()
        manager = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }

    func scan() {
        manager.scanForPeripherals(withServices: nil, options: nil)
    }

    func stop() {
        if manager.isScanning { manager.stopScan() }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: state = .poweredOn
        case .poweredOff: state = .poweredOff
        case .unauthorized: state = .unauthorized
        case .unsupported: state = .unsupported
        case .resetting: state = .resetting
        default: state = .unknown
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        found.insert(peripheral.identifier)
    }
}

private final class Locator: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var bestAccuracy: Double?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    enum Access { case undecided, allowed, denied, restricted }

    /// Off-main, because Apple warns this call can stall the main thread.
    static func servicesEnabled() async -> Bool {
        await Task.detached { CLLocationManager.locationServicesEnabled() }.value
    }

    var needsPermission: Bool { manager.authorizationStatus == .notDetermined }
    var access: Access {
        switch manager.authorizationStatus {
        case .notDetermined: return .undecided
        case .authorizedWhenInUse, .authorizedAlways: return .allowed
        case .restricted: return .restricted
        default: return .denied
        }
    }
    /// The user turned off Precise Location for this app (iOS 14 and later).
    var isApproximate: Bool { manager.accuracyAuthorization == .reducedAccuracy }

    func requestPermission() { manager.requestWhenInUseAuthorization() }
    func start() { manager.startUpdatingLocation() }
    func stop() { manager.stopUpdatingLocation() }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations where location.horizontalAccuracy >= 0 {
            bestAccuracy = min(bestAccuracy ?? .infinity, location.horizontalAccuracy)
        }
    }
}
#endif
