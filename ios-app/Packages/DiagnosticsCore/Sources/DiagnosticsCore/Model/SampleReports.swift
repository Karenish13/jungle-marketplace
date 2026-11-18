import Foundation

/// The two preloaded reports, also used by SwiftUI previews.
/// Both are stamped as simulated because they were not produced by running the tests.
public extension Report {
    static let sampleHealthy: Report = {
        let device = DeviceProfile.sampleIPhone13Pro
        return Report(
            id: "JGL-SAMP-HLTH",
            createdAt: Date(timeIntervalSince1970: 1_794_000_000),
            appVersion: "sample",
            device: device,
            results: sampleResults(for: device, failing: [:]),
            survey: .sampleHealthy,
            simulation: SimulationStamp(details: ["Sample report"])
        )
    }()

    static let samplePartsDonor: Report = {
        let device = DeviceProfile.sampleIPhone7
        let failing: [ComponentID: String] = [
            .touchscreen: "28 squares could not be painted",
            .loudspeaker: "No tone detected on any microphone",
            .rearWideCamera: "Frames were black",
        ]
        return Report(
            id: "JGL-SAMP-DONR",
            createdAt: Date(timeIntervalSince1970: 1_794_000_000),
            appVersion: "sample",
            device: device,
            results: sampleResults(for: device, failing: failing),
            survey: .samplePartsDonor,
            simulation: SimulationStamp(details: ["Sample report"])
        )
    }()

    private static func sampleResults(for device: DeviceProfile, failing: [ComponentID: String]) -> [TestResult] {
        TestPlan.testIDs(for: device.capabilities, includeTier2: true).map { test in
            TestResult(testID: test, components: test.components(for: device.capabilities).map { c in
                if let note = failing[c] {
                    return ComponentResult(c, .fail, evidence: test.evidence, note: note)
                }
                return ComponentResult(c, .pass, evidence: test.evidence)
            }, finishedAt: Date(timeIntervalSince1970: 1_794_000_000))
        }
    }
}
