import Foundation

public enum DepthVerdict {
    /// At least this share of the depth map must hold a plausible distance (0.1 to 10 m).
    public static let minimumValidShare = 0.5

    public static func evaluate(validShare: Double?) -> (TestStatus, String?) {
        guard let share = validShare else { return (.fail, "No depth data from the LiDAR scanner") }
        return share >= minimumValidShare ? (.pass, nil) : (.fail, "Depth data was mostly empty")
    }

    /// Share of depth values (metres) between 0.1 and 10.
    public static func validShare(_ depths: [Float]) -> Double {
        guard !depths.isEmpty else { return 0 }
        return Double(depths.filter { $0 > 0.1 && $0 < 10 }.count) / Double(depths.count)
    }
}

/// LiDAR: runs ARKit scene depth and checks the depth map holds real distances.
/// Broken: depth frames are ignored, as if the scanner sent nothing.
@MainActor
final class DepthTest: DiagnosticTest {
    let id = TestID.depth
    let components: [ComponentID] = [.lidar]

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        #if os(iOS)
        guard await CameraSession.requestAccess() else {
            return [ComponentResult(.lidar, .notTested, evidence: .automated, note: "Camera permission was denied")]
        }
        guard DepthScanner.isSupported else {
            return [ComponentResult(.lidar, .fail, evidence: .automated, note: "iOS reports no LiDAR scanner")]
        }
        let scanner = DepthScanner()
        scanner.start()
        defer { scanner.stop() }

        context.show(.working("Point the back camera at the room…"))
        let broken = context.faults.isBroken(.lidar)
        _ = try await context.waitUntil(timeout: 10) { !broken && scanner.latestDepths() != nil }
        let share = broken ? nil : scanner.latestDepths().map(DepthVerdict.validShare)

        let verdict = DepthVerdict.evaluate(validShare: share)
        return [ComponentResult(
            .lidar, verdict.0, evidence: .automated,
            measurements: share.map { [Measurement("Valid depth points", String(format: "%.0f%%", $0 * 100))] } ?? [],
            note: verdict.1
        )]
        #else
        return [ComponentResult(.lidar, .notTested, evidence: .automated, note: "Only on an iPhone")]
        #endif
    }
}

#if os(iOS)
import ARKit

private final class DepthScanner {
    static var isSupported: Bool { ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) }

    private let session = ARSession()

    func start() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .sceneDepth
        session.run(configuration)
    }

    func stop() { session.pause() }

    /// Every 8th depth value of the latest frame, or nil if there is no depth yet.
    func latestDepths() -> [Float]? {
        guard let map = session.currentFrame?.sceneDepth?.depthMap else { return nil }
        CVPixelBufferLockBaseAddress(map, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(map) else { return nil }
        let width = CVPixelBufferGetWidth(map), height = CVPixelBufferGetHeight(map)
        let rowBytes = CVPixelBufferGetBytesPerRow(map)
        var values: [Float] = []
        for y in stride(from: 0, to: height, by: 8) {
            let row = (base + y * rowBytes).assumingMemoryBound(to: Float32.self)
            for x in stride(from: 0, to: width, by: 8) { values.append(row[x]) }
        }
        return values
    }
}
#endif
