import Foundation

/// What a model is expected to have. The test plan is built from this, and a component the
/// model lacks is reported as "not present". Where possible tests also check at runtime, so a
/// camera that is expected but missing is a fault, not a silent skip.
public struct DeviceCapabilities: Codable, Hashable, Sendable {
    public enum Biometric: String, Codable, Sendable { case touchID, faceID }
    public enum RingerControl: String, Codable, Sendable { case muteSwitch, actionButton }
    public enum Port: String, Codable, Sendable {
        case lightning, usbC
        public var displayName: String { self == .lightning ? "Lightning" : "USB-C" }
    }

    public var biometric: Biometric
    public var rearCameras: [ComponentID]
    public var hasLiDAR: Bool
    public var has3DTouch: Bool
    public var hasBarometer: Bool
    public var ringer: RingerControl
    public var hasWirelessCharging: Bool
    public var port: Port

    /// Touch ID models are exactly the ones with a home button.
    public var hasHomeButton: Bool { biometric == .touchID }

    public init(
        biometric: Biometric,
        rearCameras: [ComponentID],
        hasLiDAR: Bool = false,
        has3DTouch: Bool = false,
        hasBarometer: Bool = true,
        ringer: RingerControl = .muteSwitch,
        hasWirelessCharging: Bool = true,
        port: Port = .lightning
    ) {
        self.biometric = biometric
        self.rearCameras = rearCameras
        self.hasLiDAR = hasLiDAR
        self.has3DTouch = has3DTouch
        self.hasBarometer = hasBarometer
        self.ringer = ringer
        self.hasWirelessCharging = hasWirelessCharging
        self.port = port
    }

    /// Whether this model has the component at all.
    public func has(_ component: ComponentID) -> Bool {
        switch component {
        case .rearWideCamera, .rearUltraWideCamera, .rearTelephotoCamera: return rearCameras.contains(component)
        case .lidar: return hasLiDAR
        case .forceTouch: return has3DTouch
        case .barometer: return hasBarometer
        case .faceID: return biometric == .faceID
        case .touchID, .homeButton: return biometric == .touchID
        case .muteSwitch: return ringer == .muteSwitch
        case .actionButton: return ringer == .actionButton
        case .wirelessCharging: return hasWirelessCharging
        default: return true
        }
    }
}
