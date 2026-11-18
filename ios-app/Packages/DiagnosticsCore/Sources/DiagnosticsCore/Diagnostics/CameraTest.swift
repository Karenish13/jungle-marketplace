import Foundation

/// Brightness statistics for one camera frame, from its luma (brightness) plane.
public struct FrameStats: Equatable, Sendable {
    /// Average brightness, 0...255.
    public var mean: Double
    /// Spread of brightness. A real scene has edges and noise; a dead sensor is flat.
    public var stdDev: Double
    public var width: Int
    public var height: Int

    public init(mean: Double, stdDev: Double, width: Int, height: Int) {
        self.mean = mean
        self.stdDev = stdDev
        self.width = width
        self.height = height
    }

    /// Samples every `step`th pixel in both directions of an 8-bit luma plane.
    public static func analyze(luma: UnsafePointer<UInt8>, width: Int, height: Int, bytesPerRow: Int, step: Int = 8) -> FrameStats {
        var sum = 0.0, sumSquares = 0.0, count = 0.0
        for y in stride(from: 0, to: height, by: step) {
            let row = luma + y * bytesPerRow
            for x in stride(from: 0, to: width, by: step) {
                let v = Double(row[x])
                sum += v
                sumSquares += v * v
                count += 1
            }
        }
        guard count > 0 else { return FrameStats(mean: 0, stdDev: 0, width: width, height: height) }
        let mean = sum / count
        return FrameStats(mean: mean, stdDev: max(0, sumSquares / count - mean * mean).squareRoot(), width: width, height: height)
    }

    /// What a broken camera produces instead of the real frame.
    public func blanked() -> FrameStats { FrameStats(mean: 0, stdDev: 0, width: width, height: height) }
}

public enum CameraVerdict {
    /// Below this average brightness the frame counts as black (lens covered or sensor dead).
    public static let minimumMean = 12.0
    /// Below this spread the frame counts as one flat colour.
    public static let minimumStdDev = 2.0

    public static func evaluate(_ stats: FrameStats) -> (status: TestStatus, note: String?) {
        if stats.mean < minimumMean { return (.fail, "Image was black") }
        if stats.stdDev < minimumStdDev { return (.fail, "Image was one flat colour") }
        return (.pass, nil)
    }
}

public enum FlashlightVerdict {
    /// The scene must get at least this much brighter (0...255 scale) with the torch on.
    public static let minimumIncrease = 8.0

    public static func evaluate(off: FrameStats, on: FrameStats) -> (status: TestStatus, note: String?) {
        if off.mean > 235 { return (.notTested, "Too bright to measure; point at something darker") }
        let increase = on.mean - off.mean
        return increase >= minimumIncrease ? (.pass, nil) : (.fail, "The scene did not get brighter with the flashlight on")
    }
}

/// The camera under test, for the screen's live preview (`TestInteraction.cameraPreview`).
public final class CameraFeed {
    /// True when the camera is simulated as broken: draw black instead of the preview.
    public let isBlanked: Bool
    #if os(iOS)
    /// Attach an `AVCaptureVideoPreviewLayer` to this session.
    public let session: AVCaptureSession

    init(session: AVCaptureSession, isBlanked: Bool) {
        self.session = session
        self.isBlanked = isBlanked
    }
    #else
    init(isBlanked: Bool) { self.isBlanked = isBlanked }
    #endif
}

/// Tests one camera: opens that lens on its own, shows a live preview while auto-exposure
/// settles, grabs a frame and checks it is not black or blank. A lens the model should have
/// but iOS cannot find is a fail.
/// Broken: the preview shows black and the frame is replaced with black before the check.
@MainActor
final class CameraTest: DiagnosticTest {
    let id: TestID
    let components: [ComponentID]

    init(id: TestID, components: [ComponentID]) {
        self.id = id
        self.components = components
    }

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        guard let camera = components.first else { return [] }
        #if os(iOS)
        guard await CameraSession.requestAccess() else {
            return [ComponentResult(camera, .notTested, evidence: .automated, note: "Camera permission was denied")]
        }
        guard let device = CameraSession.device(for: camera) else {
            return [ComponentResult(camera, .fail, evidence: .automated, note: "iOS did not find this camera")]
        }

        let broken = context.faults.isBroken(camera)
        let name = camera.displayName(on: context.device.capabilities).lowercased()

        // The camera exists but will not open or sends nothing: that is how a dead module
        // usually behaves, so it is a fail rather than an error.
        var stats: FrameStats
        do {
            let session = try CameraSession(device: device)
            session.start()
            defer { session.stop() }
            let feed = CameraFeed(session: session.captureSession, isBlanked: broken)

            // The user sees the preview while auto-exposure settles.
            context.show(.cameraPreview(camera == .frontCamera ? "Look at the screen…" : "Aim at something well lit…", feed))
            let steps = 12
            for step in 1...steps {
                context.setProgress(Double(step) / Double(steps))
                try await context.sleep(seconds: 0.25)
            }
            context.setProgress(nil)
            context.show(.cameraPreview("Checking the \(name)…", feed))
            stats = try await session.nextFrame(skip: 5)
        } catch let error as CameraSession.CaptureError {
            return [ComponentResult(camera, .fail, evidence: .automated, note: error.errorDescription)]
        }
        if broken { stats = stats.blanked() }

        let verdict = CameraVerdict.evaluate(stats)
        return [ComponentResult(
            camera, verdict.status, evidence: .automated,
            measurements: [
                Measurement("Average brightness", String(format: "%.0f of 255", stats.mean)),
                Measurement("Contrast", String(format: "%.1f", stats.stdDev)),
                Measurement("Frame size", "\(stats.width) × \(stats.height)"),
            ],
            note: verdict.note
        )]
        #else
        return [ComponentResult(camera, .notTested, evidence: .automated, note: "Cameras can only be tested on an iPhone")]
        #endif
    }
}

/// Locks the rear camera's exposure, then compares brightness with the torch off and on.
/// Broken: the torch is never switched on.
@MainActor
final class FlashlightTest: DiagnosticTest {
    let id = TestID.flashlight
    let components: [ComponentID] = [.flashlight]

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        #if os(iOS)
        guard await CameraSession.requestAccess() else {
            return [ComponentResult(.flashlight, .notTested, evidence: .automated, note: "Camera permission was denied")]
        }
        guard let device = CameraSession.device(for: .rearWideCamera), device.hasTorch else {
            return [ComponentResult(.flashlight, .fail, evidence: .automated, note: "iOS did not find the flashlight")]
        }

        try await context.countdown("Point the back of the phone at a wall or your hand, about 20 cm away…", seconds: 2)
        context.show(.working("Testing the flashlight…"))

        let session = try CameraSession(device: device)
        session.start()
        defer {
            session.setTorch(false)
            session.stop()
        }
        _ = try await session.nextFrame(skip: 20)      // let auto-exposure settle
        session.lockExposure()
        try await context.sleep(seconds: 0.3)
        let off = try await session.nextFrame(skip: 3)

        if !context.faults.isBroken(.flashlight) { session.setTorch(true) }
        try await context.sleep(seconds: 0.6)
        let on = try await session.nextFrame(skip: 3)
        session.setTorch(false)

        let verdict = FlashlightVerdict.evaluate(off: off, on: on)
        return [ComponentResult(
            .flashlight, verdict.status, evidence: .automated,
            measurements: [
                Measurement("Brightness, torch off", String(format: "%.0f", off.mean)),
                Measurement("Brightness, torch on", String(format: "%.0f", on.mean)),
            ],
            note: verdict.note
        )]
        #else
        return [ComponentResult(.flashlight, .notTested, evidence: .automated, note: "Only on an iPhone")]
        #endif
    }
}

#if os(iOS)
import AVFoundation

/// One capture session on one lens, handing out analysed frames on request.
/// All mutable state is touched only on `frameQueue`.
final class CameraSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    enum CaptureError: LocalizedError {
        case cannotOpen, noFrames

        var errorDescription: String? {
            switch self {
            case .cannotOpen: return "The camera could not be opened"
            case .noFrames: return "The camera sent no images"
            }
        }
    }

    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    /// The physical lens for a component. Asking for each lens type directly (rather than the
    /// combined dual/triple camera) means every lens is tested on its own.
    static func device(for camera: ComponentID) -> AVCaptureDevice? {
        switch camera {
        case .rearWideCamera: return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        case .rearUltraWideCamera: return AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
        case .rearTelephotoCamera: return AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
        case .frontCamera: return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        default: return nil
        }
    }

    private let device: AVCaptureDevice
    private let session = AVCaptureSession()
    /// For the on-screen preview.
    var captureSession: AVCaptureSession { session }
    private let frameQueue = DispatchQueue(label: "jungle.camera.frames")
    private let sessionQueue = DispatchQueue(label: "jungle.camera.session")
    private var pending: (id: Int, skip: Int, continuation: CheckedContinuation<FrameStats, Error>)?
    private var nextRequestID = 0

    init(device: AVCaptureDevice) throws {
        self.device = device
        super.init()
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if session.canSetSessionPreset(.medium) { session.sessionPreset = .medium }
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            throw CaptureError.cannotOpen
        }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: frameQueue)
        guard session.canAddOutput(output) else { throw CaptureError.cannotOpen }
        session.addOutput(output)
    }

    func start() {
        sessionQueue.async { self.session.startRunning() }
    }

    func stop() {
        sessionQueue.async { self.session.stopRunning() }
        frameQueue.async { self.complete(self.pending?.id, .failure(CancellationError())) }
    }

    /// Analyses the frame after skipping `skip` frames.
    func nextFrame(skip: Int = 0, timeout: Double = 5) async throws -> FrameStats {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                frameQueue.async {
                    self.complete(self.pending?.id, .failure(CancellationError()))
                    self.nextRequestID += 1
                    let id = self.nextRequestID
                    self.pending = (id, skip, continuation)
                    self.frameQueue.asyncAfter(deadline: .now() + timeout) {
                        self.complete(id, .failure(CaptureError.noFrames))
                    }
                }
            }
        } onCancel: {
            frameQueue.async { self.complete(self.pending?.id, .failure(CancellationError())) }
        }
    }

    func lockExposure() {
        guard (try? device.lockForConfiguration()) != nil else { return }
        if device.isExposureModeSupported(.locked) { device.exposureMode = .locked }
        if device.isWhiteBalanceModeSupported(.locked) { device.whiteBalanceMode = .locked }
        device.unlockForConfiguration()
    }

    func setTorch(_ on: Bool) {
        guard device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard var request = pending else { return }
        if request.skip > 0 {
            request.skip -= 1
            pending = request
            return
        }
        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pixels, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(pixels, 0) else { return }

        let stats = FrameStats.analyze(
            luma: base.assumingMemoryBound(to: UInt8.self),
            width: CVPixelBufferGetWidthOfPlane(pixels, 0),
            height: CVPixelBufferGetHeightOfPlane(pixels, 0),
            bytesPerRow: CVPixelBufferGetBytesPerRowOfPlane(pixels, 0)
        )
        complete(request.id, .success(stats))
    }

    /// Call on `frameQueue`. Resumes the matching request exactly once.
    private func complete(_ id: Int?, _ result: Result<FrameStats, Error>) {
        guard let id, let request = pending, request.id == id else { return }
        pending = nil
        request.continuation.resume(with: result)
    }
}
#endif
