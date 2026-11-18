import Foundation

/// Every hardware component the report can mention. Raw values are stored in report JSON,
/// so never rename one; add new cases instead.
public enum ComponentID: String, Codable, CaseIterable, Sendable {
    // Screen
    case touchscreen, display, multiTouch, forceTouch
    // Audio
    case loudspeaker, earpiece, bottomMic, frontMic, backMic
    // Cameras and depth
    case rearWideCamera, rearUltraWideCamera, rearTelephotoCamera, frontCamera, lidar
    // Biometrics
    case faceID, touchID
    // Sensors
    case accelerometer, gyroscope, compass, barometer, proximity
    // Buttons
    case volumeButtons, sideButton, homeButton, muteSwitch, actionButton
    // Power
    case chargingPort, wirelessCharging, battery
    // Radios
    case wifi, bluetooth, cellular, gps
    // Other
    case flashlight, haptics

    public var displayName: String {
        switch self {
        case .touchscreen: return "Touchscreen"
        case .display: return "Display"
        case .multiTouch: return "Multi-touch"
        case .forceTouch: return "3D Touch"
        case .loudspeaker: return "Loudspeaker"
        case .earpiece: return "Earpiece"
        case .bottomMic: return "Bottom microphone"
        case .frontMic: return "Front microphone"
        case .backMic: return "Back microphone"
        case .rearWideCamera: return "Rear camera (wide)"
        case .rearUltraWideCamera: return "Rear camera (ultra wide)"
        case .rearTelephotoCamera: return "Rear camera (telephoto)"
        case .frontCamera: return "Front camera"
        case .lidar: return "LiDAR scanner"
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .accelerometer: return "Accelerometer"
        case .gyroscope: return "Gyroscope"
        case .compass: return "Compass"
        case .barometer: return "Barometer"
        case .proximity: return "Proximity sensor"
        case .volumeButtons: return "Volume buttons"
        case .sideButton: return "Side button"
        case .homeButton: return "Home button"
        case .muteSwitch: return "Mute switch"
        case .actionButton: return "Action button"
        case .chargingPort: return "Charging port"
        case .wirelessCharging: return "Wireless charging"
        case .battery: return "Battery"
        case .wifi: return "Wi-Fi"
        case .bluetooth: return "Bluetooth"
        case .cellular: return "Cellular"
        case .gps: return "GPS"
        case .flashlight: return "Flashlight"
        case .haptics: return "Haptics"
        }
    }

    /// The name to show for this phone: a model with one rear camera calls it just "Rear camera".
    public func displayName(on caps: DeviceCapabilities) -> String {
        if self == .rearWideCamera && caps.rearCameras.count <= 1 { return "Rear camera" }
        return displayName
    }

    /// The replaceable part this component belongs to, for the report's parts view.
    /// The mapping is approximate: flex-cable layouts differ between generations.
    public var part: ReplaceablePart {
        switch self {
        case .touchscreen, .display, .multiTouch, .forceTouch: return .screenAssembly
        case .earpiece, .frontMic, .proximity: return .earpieceAssembly
        case .frontCamera, .faceID: return .frontCamera
        case .rearWideCamera, .rearUltraWideCamera, .rearTelephotoCamera, .lidar: return .rearCamera
        case .loudspeaker: return .loudspeaker
        case .chargingPort, .bottomMic: return .chargePort
        case .battery: return .battery
        case .haptics: return .tapticEngine
        case .volumeButtons, .sideButton, .muteSwitch, .actionButton, .flashlight, .backMic: return .buttonFlex
        case .homeButton, .touchID: return .homeButton
        case .wirelessCharging: return .wirelessChargingCoil
        case .accelerometer, .gyroscope, .compass, .barometer, .wifi, .bluetooth, .cellular, .gps:
            return .logicBoard
        }
    }
}

/// Parts a repairer would buy or harvest as a unit.
public enum ReplaceablePart: String, Codable, CaseIterable, Sendable {
    case screenAssembly, battery, rearCamera, frontCamera, earpieceAssembly, loudspeaker,
         chargePort, tapticEngine, buttonFlex, homeButton, wirelessChargingCoil, logicBoard

    public var displayName: String {
        switch self {
        case .screenAssembly: return "Screen assembly"
        case .battery: return "Battery"
        case .rearCamera: return "Rear camera module"
        case .frontCamera: return "Front camera / Face ID module"
        case .earpieceAssembly: return "Earpiece assembly"
        case .loudspeaker: return "Loudspeaker"
        case .chargePort: return "Charge port assembly"
        case .tapticEngine: return "Taptic Engine"
        case .buttonFlex: return "Button and flash flex"
        case .homeButton: return "Home button / Touch ID"
        case .wirelessChargingCoil: return "Wireless charging coil"
        case .logicBoard: return "Logic board"
        }
    }

    /// The name to show for this phone: the front camera module only mentions Face ID on Face ID phones.
    public func displayName(on caps: DeviceCapabilities) -> String {
        if self == .frontCamera && caps.biometric != .faceID { return "Front camera" }
        return displayName
    }
}
