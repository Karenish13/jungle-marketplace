import Foundation

/// Reads the model identifier, storage and OS version of the phone the app is running on.
public enum DeviceDetector {
    /// - Parameter overrideIdentifier: developer "pretend to be" model (`FaultInjector.deviceOverride`).
    public static func detect(overrideIdentifier: String? = nil) -> DeviceProfile {
        let actual = currentModelIdentifier()
        let identifier = overrideIdentifier ?? actual
        let known = DeviceCatalog.model(for: identifier)
        let model = known ?? DeviceCatalog.unknown(identifier: identifier)
        let storage = storageBytes()

        return DeviceProfile(
            modelIdentifier: identifier,
            modelName: model.name,
            isRecognized: known != nil,
            capabilities: model.capabilities,
            storageGB: marketedCapacityGB(totalBytes: storage.total),
            freeStorageBytes: storage.free,
            osVersion: osVersion(),
            actualModelIdentifier: overrideIdentifier == nil ? nil : actual
        )
    }

    /// e.g. "iPhone9,1". In the Simulator this is the simulated model.
    public static func currentModelIdentifier() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    public static func osVersion() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return v.patchVersion == 0 ? "\(v.majorVersion).\(v.minorVersion)" : "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    static func storageBytes() -> (total: Int64, free: Int64) {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? home.resourceValues(forKeys: keys) else { return (0, 0) }
        return (Int64(values.volumeTotalCapacity ?? 0), values.volumeAvailableCapacityForImportantUsage ?? 0)
    }

    /// The OS reports slightly less than the box says (a "64 GB" phone shows about 63.9 GB),
    /// so round up to the next size Apple sells.
    /// Returns 0 when the capacity could not be read, which the profile shows as "Unknown".
    public static func marketedCapacityGB(totalBytes: Int64) -> Int {
        guard totalBytes > 0 else { return 0 }
        let gb = Double(totalBytes) / 1_000_000_000
        let sizes = [16, 32, 64, 128, 256, 512, 1024, 2048]
        return sizes.first { Double($0) >= gb } ?? Int(gb.rounded())
    }
}
