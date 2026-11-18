import Foundation

public enum PlanMode: String, CaseIterable, Sendable {
    /// Every applicable test.
    case full
    /// About two minutes, for expo visitors.
    case quickDemo
}

public extension TestID {
    /// The components this test reports on for a given phone.
    func components(for caps: DeviceCapabilities) -> [ComponentID] {
        switch self {
        case .touchscreen: return [.touchscreen]
        case .display: return [.display]
        case .audioLoopback: return [.loudspeaker, .bottomMic, .frontMic, .backMic]
        case .earpiece: return [.earpiece]
        case .rearWideCamera: return caps.has(.rearWideCamera) ? [.rearWideCamera] : []
        case .rearUltraWideCamera: return caps.has(.rearUltraWideCamera) ? [.rearUltraWideCamera] : []
        case .rearTelephotoCamera: return caps.has(.rearTelephotoCamera) ? [.rearTelephotoCamera] : []
        case .frontCamera: return [.frontCamera]
        case .motionSensors: return [.accelerometer, .gyroscope, .compass] + (caps.hasBarometer ? [.barometer] : [])
        case .volumeButtons: return [.volumeButtons]
        case .sideButton: return [.sideButton]
        case .homeButton: return caps.hasHomeButton ? [.homeButton] : []
        case .chargingPort: return [.chargingPort]
        case .biometrics: return [caps.biometric == .faceID ? .faceID : .touchID]
        case .multiTouch: return [.multiTouch]
        case .forceTouch: return caps.has3DTouch ? [.forceTouch] : []
        case .haptics: return [.haptics]
        case .ringerControl: return [caps.ringer == .muteSwitch ? .muteSwitch : .actionButton]
        case .proximity: return [.proximity]
        case .flashlight: return [.flashlight]
        case .depth: return caps.hasLiDAR ? [.lidar] : []
        case .wifi: return [.wifi]
        case .bluetooth: return [.bluetooth]
        case .cellular: return [.cellular]
        case .gps: return [.gps]
        case .wirelessCharging: return caps.hasWirelessCharging ? [.wirelessCharging] : []
        }
    }

    /// The evidence type the test produces (used for skipped and overridden results too).
    var evidence: Evidence {
        switch self {
        case .display, .earpiece, .haptics, .ringerControl: return .userConfirmed
        default: return .automated
        }
    }

}

public enum TestPlan {
    static let quickDemoTests: [TestID] = [.touchscreen, .audioLoopback, .haptics, .rearWideCamera, .frontCamera, .motionSensors, .volumeButtons]

    /// The tests to run, in order. A test is left out when the phone has none of its components.
    public static func testIDs(for caps: DeviceCapabilities, mode: PlanMode = .full, includeTier2: Bool = false) -> [TestID] {
        let candidates = mode == .quickDemo ? quickDemoTests : TestID.allCases.filter { includeTier2 || $0.tier == 1 }
        return candidates.filter { !$0.components(for: caps).isEmpty }
    }

    @MainActor
    public static func makeTest(_ id: TestID, caps: DeviceCapabilities) -> DiagnosticTest {
        let components = id.components(for: caps)
        switch id {
        case .touchscreen: return TouchscreenTest()
        case .display: return DisplayTest()
        case .audioLoopback: return AudioLoopbackTest()
        case .earpiece: return EarpieceTest()
        case .rearWideCamera, .rearUltraWideCamera, .rearTelephotoCamera, .frontCamera:
            return CameraTest(id: id, components: components)
        case .motionSensors: return MotionTest(components: components)
        case .volumeButtons: return VolumeButtonsTest()
        case .sideButton: return SideButtonTest()
        case .homeButton: return HomeButtonTest()
        case .chargingPort: return ChargingTest(id: id, component: .chargingPort)
        case .biometrics: return BiometricTest(components: components)
        case .multiTouch: return MultiTouchTest()
        case .forceTouch: return ForceTouchTest()
        case .haptics: return HapticsTest()
        case .ringerControl: return RingerControlTest(components: components)
        case .proximity: return ProximityTest()
        case .flashlight: return FlashlightTest()
        case .depth: return DepthTest()
        case .wifi: return NetworkTest(id: id, component: .wifi)
        case .bluetooth: return BluetoothTest()
        case .cellular: return NetworkTest(id: id, component: .cellular)
        case .gps: return GPSTest()
        case .wirelessCharging: return ChargingTest(id: id, component: .wirelessCharging)
        }
    }

    @MainActor
    public static func makeTests(for caps: DeviceCapabilities, mode: PlanMode = .full, includeTier2: Bool = false) -> [DiagnosticTest] {
        testIDs(for: caps, mode: mode, includeTier2: includeTier2).map { makeTest($0, caps: caps) }
    }
}
