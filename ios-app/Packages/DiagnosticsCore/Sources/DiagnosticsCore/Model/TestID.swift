import Foundation

/// One entry per diagnostic screen. Raw values are stored in report JSON; never rename one.
/// Declaration order is the order tests run in.
public enum TestID: String, Codable, CaseIterable, Sendable {
    // Tier 1
    case touchscreen
    case display
    case audioLoopback
    case earpiece
    case haptics
    case rearWideCamera
    case rearUltraWideCamera
    case rearTelephotoCamera
    case frontCamera
    case motionSensors
    case volumeButtons
    case sideButton
    case homeButton
    case chargingPort
    case biometrics
    // Tier 2
    case multiTouch
    case forceTouch
    case ringerControl
    case proximity
    case flashlight
    case depth
    case wifi
    case bluetooth
    case cellular
    case gps
    case wirelessCharging

    /// Tier 1 tests are in the default plan; tier 2 tests are optional.
    public var tier: Int {
        switch self {
        case .touchscreen, .display, .audioLoopback, .earpiece, .haptics,
             .rearWideCamera, .rearUltraWideCamera, .rearTelephotoCamera, .frontCamera, .motionSensors,
             .volumeButtons, .sideButton, .homeButton, .chargingPort, .biometrics:
            return 1
        default:
            return 2
        }
    }

    public var title: String {
        switch self {
        case .touchscreen: return "Touchscreen"
        case .display: return "Display"
        case .audioLoopback: return "Speaker and microphones"
        case .earpiece: return "Earpiece"
        case .rearWideCamera: return "Rear camera (wide)"
        case .rearUltraWideCamera: return "Rear camera (ultra wide)"
        case .rearTelephotoCamera: return "Rear camera (telephoto)"
        case .frontCamera: return "Front camera"
        case .motionSensors: return "Motion sensors"
        case .volumeButtons: return "Volume buttons"
        case .sideButton: return "Side button"
        case .homeButton: return "Home button"
        case .chargingPort: return "Charging port"
        case .biometrics: return "Face ID / Touch ID"
        case .multiTouch: return "Multi-touch"
        case .forceTouch: return "3D Touch"
        case .haptics: return "Vibration"
        case .ringerControl: return "Mute switch / Action button"
        case .proximity: return "Proximity sensor"
        case .flashlight: return "Flashlight"
        case .depth: return "LiDAR"
        case .wifi: return "Wi-Fi"
        case .bluetooth: return "Bluetooth"
        case .cellular: return "Cellular"
        case .gps: return "GPS"
        case .wirelessCharging: return "Wireless charging"
        }
    }

    /// The title to show for this phone: a model with one rear camera calls it just "Rear camera".
    public func title(on caps: DeviceCapabilities) -> String {
        if self == .rearWideCamera && caps.rearCameras.count <= 1 { return "Rear camera" }
        return title
    }

    /// Text for the top of the test screen, before the user taps Start.
    public var instructions: String {
        switch self {
        case .touchscreen: return "Drag your finger over every square until the whole screen is filled in."
        case .display: return "The screen will show solid colours. Look for dead pixels, burn-in, odd tints or bright patches at the edges."
        case .audioLoopback: return "Put the phone on a table. It will play a short tone and listen with each microphone."
        case .earpiece: return "Hold the phone to your ear like a call. A tone will play from the earpiece."
        case .rearWideCamera, .rearUltraWideCamera, .rearTelephotoCamera:
            return "Point the back of the phone at something well lit, about an arm's length away. Keep your fingers off the lenses."
        case .frontCamera: return "Hold the phone up and look at the screen, in good light."
        case .motionSensors: return "Pick up the phone, tilt it and turn it around slowly."
        case .volumeButtons: return "Press volume up, then volume down."
        case .sideButton: return "Press the side button to lock the screen, then unlock the phone and come back."
        case .homeButton: return "Press the home button, then open this app again."
        case .chargingPort: return "Plug in a charging cable."
        case .biometrics: return "Face ID or Touch ID must already be set up in Settings, with a passcode. If it isn't, skip this test: it will show as not tested, not failed. Otherwise, use it when the prompt appears."
        case .multiTouch: return "Put several fingers on the screen at once."
        case .forceTouch: return "Press firmly on the circle."
        case .haptics: return "Hold the phone in your hand. It will vibrate a few times, then ask whether you felt it."
        case .ringerControl: return "Flip the mute switch, or press the Action button."
        case .proximity: return "Cover the top of the screen with your hand."
        case .flashlight: return "Point the phone at a wall. The flashlight will blink."
        case .depth: return "Point the rear camera at the room."
        case .wifi: return "Make sure Wi-Fi is on."
        case .bluetooth: return "Make sure Bluetooth is on."
        case .cellular: return "Needs a SIM or eSIM with data."
        case .gps: return "Go near a window if you are indoors."
        case .wirelessCharging: return "Put the phone on a wireless charger."
        }
    }
}
