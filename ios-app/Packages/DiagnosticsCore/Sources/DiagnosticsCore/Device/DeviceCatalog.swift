import Foundation

public struct DeviceModel: Hashable, Sendable {
    public var name: String
    public var identifiers: [String]
    public var capabilities: DeviceCapabilities
}

/// Model identifier (e.g. "iPhone9,1") to capability table, for every iPhone that runs iOS 15
/// or later. Identifiers checked against Xcode 27.2 simulator profiles, November 2026.
/// A model released after this table falls back to `DeviceCatalog.unknown`.
public enum DeviceCatalog {
    private static let wide: [ComponentID] = [.rearWideCamera]
    private static let wideTele: [ComponentID] = [.rearWideCamera, .rearTelephotoCamera]
    private static let dual: [ComponentID] = [.rearWideCamera, .rearUltraWideCamera]
    private static let triple: [ComponentID] = [.rearWideCamera, .rearUltraWideCamera, .rearTelephotoCamera]

    private static func touchID(_ cams: [ComponentID], threeD: Bool, wireless: Bool, barometer: Bool = true) -> DeviceCapabilities {
        DeviceCapabilities(biometric: .touchID, rearCameras: cams, has3DTouch: threeD,
                           hasBarometer: barometer, hasWirelessCharging: wireless)
    }

    private static func faceID(_ cams: [ComponentID], lidar: Bool = false, threeD: Bool = false,
                               action: Bool = false, usbC: Bool = false) -> DeviceCapabilities {
        DeviceCapabilities(biometric: .faceID, rearCameras: cams, hasLiDAR: lidar, has3DTouch: threeD,
                           ringer: action ? .actionButton : .muteSwitch, port: usbC ? .usbC : .lightning)
    }

    private static func m(_ name: String, _ ids: [String], _ caps: DeviceCapabilities) -> DeviceModel {
        DeviceModel(name: name, identifiers: ids, capabilities: caps)
    }

    public static let models: [DeviceModel] = [
        m("iPhone 6s", ["iPhone8,1"], touchID(wide, threeD: true, wireless: false)),
        m("iPhone 6s Plus", ["iPhone8,2"], touchID(wide, threeD: true, wireless: false)),
        m("iPhone SE (1st generation)", ["iPhone8,4"], touchID(wide, threeD: false, wireless: false, barometer: false)),
        m("iPhone 7", ["iPhone9,1", "iPhone9,3"], touchID(wide, threeD: true, wireless: false)),
        m("iPhone 7 Plus", ["iPhone9,2", "iPhone9,4"], touchID(wideTele, threeD: true, wireless: false)),
        m("iPhone 8", ["iPhone10,1", "iPhone10,4"], touchID(wide, threeD: true, wireless: true)),
        m("iPhone 8 Plus", ["iPhone10,2", "iPhone10,5"], touchID(wideTele, threeD: true, wireless: true)),
        m("iPhone X", ["iPhone10,3", "iPhone10,6"], faceID(wideTele, threeD: true)),
        m("iPhone XS", ["iPhone11,2"], faceID(wideTele, threeD: true)),
        m("iPhone XS Max", ["iPhone11,4", "iPhone11,6"], faceID(wideTele, threeD: true)),
        m("iPhone XR", ["iPhone11,8"], faceID(wide)),
        m("iPhone 11", ["iPhone12,1"], faceID(dual)),
        m("iPhone 11 Pro", ["iPhone12,3"], faceID(triple)),
        m("iPhone 11 Pro Max", ["iPhone12,5"], faceID(triple)),
        m("iPhone SE (2nd generation)", ["iPhone12,8"], touchID(wide, threeD: false, wireless: true)),
        m("iPhone 12 mini", ["iPhone13,1"], faceID(dual)),
        m("iPhone 12", ["iPhone13,2"], faceID(dual)),
        m("iPhone 12 Pro", ["iPhone13,3"], faceID(triple, lidar: true)),
        m("iPhone 12 Pro Max", ["iPhone13,4"], faceID(triple, lidar: true)),
        m("iPhone 13 mini", ["iPhone14,4"], faceID(dual)),
        m("iPhone 13", ["iPhone14,5"], faceID(dual)),
        m("iPhone 13 Pro", ["iPhone14,2"], faceID(triple, lidar: true)),
        m("iPhone 13 Pro Max", ["iPhone14,3"], faceID(triple, lidar: true)),
        m("iPhone SE (3rd generation)", ["iPhone14,6"], touchID(wide, threeD: false, wireless: true)),
        m("iPhone 14", ["iPhone14,7"], faceID(dual)),
        m("iPhone 14 Plus", ["iPhone14,8"], faceID(dual)),
        m("iPhone 14 Pro", ["iPhone15,2"], faceID(triple, lidar: true)),
        m("iPhone 14 Pro Max", ["iPhone15,3"], faceID(triple, lidar: true)),
        m("iPhone 15", ["iPhone15,4"], faceID(dual, usbC: true)),
        m("iPhone 15 Plus", ["iPhone15,5"], faceID(dual, usbC: true)),
        m("iPhone 15 Pro", ["iPhone16,1"], faceID(triple, lidar: true, action: true, usbC: true)),
        m("iPhone 15 Pro Max", ["iPhone16,2"], faceID(triple, lidar: true, action: true, usbC: true)),
        m("iPhone 16", ["iPhone17,3"], faceID(dual, action: true, usbC: true)),
        m("iPhone 16 Plus", ["iPhone17,4"], faceID(dual, action: true, usbC: true)),
        m("iPhone 16 Pro", ["iPhone17,1"], faceID(triple, lidar: true, action: true, usbC: true)),
        m("iPhone 16 Pro Max", ["iPhone17,2"], faceID(triple, lidar: true, action: true, usbC: true)),
        m("iPhone 16e", ["iPhone17,5"], faceID(wide, action: true, usbC: true)),
        m("iPhone 17", ["iPhone18,3"], faceID(dual, action: true, usbC: true)),
        m("iPhone Air", ["iPhone18,4"], faceID(wide, action: true, usbC: true)),
        m("iPhone 17 Pro", ["iPhone18,1"], faceID(triple, lidar: true, action: true, usbC: true)),
        m("iPhone 17 Pro Max", ["iPhone18,2"], faceID(triple, lidar: true, action: true, usbC: true)),
        m("iPhone 17e", ["iPhone18,5"], faceID(wide, action: true, usbC: true)),
        // Identifiers from Xcode 27's simulator profiles. Capabilities assumed to match the 17 Pro;
        // check on a real phone. "iPhone Duo" (iPhone19,4) is left to the unknown fallback.
        m("iPhone 18 Pro", ["iPhone19,2"], faceID(triple, lidar: true, action: true, usbC: true)),
        m("iPhone 18 Pro Max", ["iPhone19,3"], faceID(triple, lidar: true, action: true, usbC: true)),
    ]

    /// Used when the identifier is not in the table. Guesses a recent Face ID phone; the device
    /// screen should tell the user the model was not recognised.
    public static func unknown(identifier: String) -> DeviceModel {
        m("Unrecognised iPhone (\(identifier))", [identifier], faceID(dual, action: true, usbC: true))
    }

    private static let byIdentifier: [String: DeviceModel] = {
        var map: [String: DeviceModel] = [:]
        for model in models {
            for id in model.identifiers { map[id] = model }
        }
        return map
    }()

    public static func model(for identifier: String) -> DeviceModel? {
        byIdentifier[identifier]
    }
}
