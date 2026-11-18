import Foundation

/// The phone under test, as shown in the report header. Built by `DeviceDetector`;
/// the device confirmation screen lets the user fill in `colour` and confirm the rest.
public struct DeviceProfile: Codable, Hashable, Sendable {
    /// e.g. "iPhone9,1". When a developer override is active this is the pretend identifier.
    public var modelIdentifier: String
    public var modelName: String
    /// False when the identifier was not in `DeviceCatalog` and capabilities are a guess.
    public var isRecognized: Bool
    public var capabilities: DeviceCapabilities
    /// Marketed capacity in GB (64, 128, ...), rounded up from what the OS reports.
    public var storageGB: Int
    public var freeStorageBytes: Int64
    public var osVersion: String
    /// Not readable by the app; the user picks or types it.
    public var colour: String?
    /// The real identifier, set only when a developer override changed `modelIdentifier`.
    public var actualModelIdentifier: String?

    public init(
        modelIdentifier: String,
        modelName: String,
        isRecognized: Bool,
        capabilities: DeviceCapabilities,
        storageGB: Int,
        freeStorageBytes: Int64,
        osVersion: String,
        colour: String? = nil,
        actualModelIdentifier: String? = nil
    ) {
        self.modelIdentifier = modelIdentifier
        self.modelName = modelName
        self.isRecognized = isRecognized
        self.capabilities = capabilities
        self.storageGB = storageGB
        self.freeStorageBytes = freeStorageBytes
        self.osVersion = osVersion
        self.colour = colour
        self.actualModelIdentifier = actualModelIdentifier
    }

    public var storageDescription: String {
        if storageGB <= 0 { return "Unknown" }
        return storageGB >= 1024 ? "\(storageGB / 1024) TB" : "\(storageGB) GB"
    }
}

public extension DeviceProfile {
    static let sampleIPhone7 = DeviceProfile(
        modelIdentifier: "iPhone9,1", modelName: "iPhone 7", isRecognized: true,
        capabilities: DeviceCatalog.model(for: "iPhone9,1")!.capabilities,
        storageGB: 32, freeStorageBytes: 9_800_000_000, osVersion: "15.8.3", colour: "Black"
    )

    static let sampleIPhone13Pro = DeviceProfile(
        modelIdentifier: "iPhone14,2", modelName: "iPhone 13 Pro", isRecognized: true,
        capabilities: DeviceCatalog.model(for: "iPhone14,2")!.capabilities,
        storageGB: 128, freeStorageBytes: 41_200_000_000, osVersion: "18.6", colour: "Sierra Blue"
    )
}
