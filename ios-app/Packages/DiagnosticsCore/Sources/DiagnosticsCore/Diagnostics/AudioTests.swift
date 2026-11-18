import Foundation

/// Detects a test tone in a recording, using the Goertzel algorithm (the power at one frequency).
public enum ToneAnalysis {
    /// 2 kHz: phone speakers and mics handle it well, and most crowd noise is lower.
    public static let testFrequency = 2000.0
    /// The tone must be this many times stronger than the neighbouring frequencies.
    public static let minimumRatio = 10.0

    /// Power of `frequency` in the samples.
    public static func power(_ samples: [Float], frequency: Double, sampleRate: Double) -> Double {
        guard !samples.isEmpty, sampleRate > 0 else { return 0 }
        let coefficient = 2 * cos(2 * Double.pi * frequency / sampleRate)
        var s1 = 0.0, s2 = 0.0
        for sample in samples {
            let s0 = Double(sample) + coefficient * s1 - s2
            s2 = s1
            s1 = s0
        }
        let n = Double(samples.count)
        return (s1 * s1 + s2 * s2 - coefficient * s1 * s2) / (n * n)
    }

    /// How much stronger the test tone is than nearby frequencies. Silence gives 0.
    public static func toneRatio(_ samples: [Float], frequency: Double = testFrequency, sampleRate: Double) -> Double {
        let tone = power(samples, frequency: frequency, sampleRate: sampleRate)
        let neighbours = [-600.0, -400.0, 400.0, 600.0].map { power(samples, frequency: frequency + $0, sampleRate: sampleRate) }
        let noise = neighbours.reduce(0, +) / Double(neighbours.count)
        if tone < 1e-12 { return 0 }
        return tone / max(noise, 1e-12)
    }

    public static func containsTone(_ samples: [Float], sampleRate: Double) -> Bool {
        toneRatio(samples, sampleRate: sampleRate) >= minimumRatio
    }

    public static func sine(frequency: Double, sampleRate: Double, seconds: Double, amplitude: Float = 0.8) -> [Float] {
        let count = Int(sampleRate * seconds)
        let fade = min(count / 2, Int(sampleRate * 0.01))   // 10 ms fade in/out to avoid clicks
        return (0..<count).map { i in
            var gain = amplitude
            if i < fade { gain *= Float(i) / Float(fade) }
            if i > count - fade { gain *= Float(count - i) / Float(fade) }
            return gain * Float(sin(2 * Double.pi * frequency * Double(i) / sampleRate))
        }
    }
}

/// Plays a tone on the loudspeaker and records it with each microphone in turn.
///
/// If at least one mic hears the tone, the loudspeaker works and each mic passes or fails on
/// its own. If no mic hears anything, the user is asked whether they heard the beep, to tell a
/// dead speaker from a noisy room. Broken loudspeaker: plays silence. Broken mic: records silence.
@MainActor
final class AudioLoopbackTest: DiagnosticTest {
    let id = TestID.audioLoopback
    let components: [ComponentID] = [.loudspeaker, .bottomMic, .frontMic, .backMic]
    private let mics: [ComponentID] = [.bottomMic, .frontMic, .backMic]

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        #if os(iOS)
        let faults = context.faults
        let speakerFrequency: Double? = faults.isBroken(.loudspeaker) ? nil : ToneAnalysis.testFrequency
        defer { AudioRig.deactivate() }

        let micAllowed = await AudioRig.requestMicAccess()
        if faults.forceUserConfirmedAudio || !micAllowed {
            let note = micAllowed ? "Microphone check turned off for this event" : "Microphone permission was denied"
            let speaker = try await askAboutSpeaker(context, frequency: speakerFrequency)
            return [speaker] + mics.map { ComponentResult($0, .notTested, evidence: .automated, note: note) }
        }

        try AudioRig.configure(speaker: true)
        try await AudioRig.ensureVolume(context)

        var micResults: [ComponentID: ComponentResult] = [:]
        for (index, mic) in mics.enumerated() {
            context.show(.working("Listening with the \(mic.displayName.lowercased())…"))
            context.setProgress(Double(index) / Double(mics.count))
            guard try AudioRig.selectMic(mic) else {
                micResults[mic] = ComponentResult(mic, .notTested, evidence: .automated,
                                                  note: "iOS does not offer this microphone separately")
                continue
            }
            try await context.sleep(seconds: 0.3)   // let the route settle

            var ratio = 0.0
            for _ in 0..<2 {   // one retry, for a noisy room
                var recording = try await AudioRig.playAndRecord(frequency: speakerFrequency, seconds: 0.9)
                if faults.isBroken(mic) { recording.samples = [Float](repeating: 0, count: recording.samples.count) }
                ratio = ToneAnalysis.toneRatio(recording.samples, sampleRate: recording.sampleRate)
                if ratio >= ToneAnalysis.minimumRatio { break }
            }
            let heard = ratio >= ToneAnalysis.minimumRatio
            micResults[mic] = ComponentResult(mic, heard ? .pass : .fail, evidence: .automated,
                                              measurements: [Measurement("Tone strength", String(format: "%.0f×", ratio))],
                                              note: heard ? nil : "Did not hear the test tone")
        }
        context.setProgress(nil)

        let anyHeard = micResults.values.contains { $0.status == .pass }
        if anyHeard {
            let speaker = ComponentResult(.loudspeaker, .pass, evidence: .automated, note: "Heard by at least one microphone")
            return [speaker] + mics.compactMap { micResults[$0] }
        }

        // Nothing heard: is the speaker dead, or the mics, or the room too loud?
        let speaker = try await askAboutSpeaker(context, frequency: speakerFrequency)
        if speaker.status == .pass {
            return [speaker] + mics.compactMap { micResults[$0] }
        }
        return [speaker] + mics.map {
            ComponentResult($0, .notTested, evidence: .automated, note: "Could not check without a working loudspeaker")
        }
        #else
        return components.map { ComponentResult($0, .notTested, evidence: .automated, note: "Only on an iPhone") }
        #endif
    }

    #if os(iOS)
    private func askAboutSpeaker(_ context: TestContext, frequency: Double?) async throws -> ComponentResult {
        try AudioRig.configure(speaker: true)
        try await AudioRig.ensureVolume(context)
        context.show(.working("Listen for a beep from the bottom of the phone…"))
        try await AudioRig.play(frequency: frequency, seconds: 1.2)
        let heard = try await context.askYesNo("Did you hear a beep from the bottom of the phone?")
        return ComponentResult(.loudspeaker, heard ? .pass : .fail, evidence: .userConfirmed,
                               note: heard ? nil : "No sound from the loudspeaker")
    }
    #endif
}

/// Plays a tone through the earpiece; the user says whether they heard it.
/// Broken: plays silence.
@MainActor
final class EarpieceTest: DiagnosticTest {
    let id = TestID.earpiece
    let components: [ComponentID] = [.earpiece]

    func run(_ context: TestContext) async throws -> [ComponentResult] {
        #if os(iOS)
        defer { AudioRig.deactivate() }
        try AudioRig.configure(speaker: false)
        try await context.countdown("Hold the phone to your ear like a call…", seconds: 3)
        context.show(.working("Playing a tone in the earpiece…"))
        let frequency: Double? = context.faults.isBroken(.earpiece) ? nil : 1000
        try await AudioRig.play(frequency: frequency, seconds: 2)
        let heard = try await context.askYesNo("Did you hear a tone from the earpiece at the top of the phone?")
        return [ComponentResult(.earpiece, heard ? .pass : .fail, evidence: .userConfirmed,
                                note: heard ? nil : "No sound from the earpiece")]
        #else
        return [ComponentResult(.earpiece, .notTested, evidence: .userConfirmed, note: "Only on an iPhone")]
        #endif
    }
}

#if os(iOS)
import AVFoundation

/// Thin wrapper over AVAudioSession and AVAudioEngine for the audio tests.
@MainActor
enum AudioRig {
    private static var session: AVAudioSession { AVAudioSession.sharedInstance() }

    static func requestMicAccess() async -> Bool {
        switch session.recordPermission {
        case .granted: return true
        case .denied: return false
        default:
            return await withCheckedContinuation { continuation in
                session.requestRecordPermission { continuation.resume(returning: $0) }
            }
        }
    }

    /// `speaker` true routes to the bottom loudspeaker, false to the earpiece.
    /// Measurement mode turns off automatic gain and noise suppression.
    static func configure(speaker: Bool) throws {
        try session.setCategory(.playAndRecord, mode: .measurement, options: speaker ? [.defaultToSpeaker] : [])
        try session.setActive(true)
        try session.overrideOutputAudioPort(speaker ? .speaker : .none)
    }

    static func deactivate() {
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Asks the user to turn the volume up if it is too low for the test to work.
    static func ensureVolume(_ context: TestContext) async throws {
        guard session.outputVolume < 0.4 else { return }
        _ = try await context.waitForAction("Turn the volume up with the volume buttons", timeout: 15) {
            AVAudioSession.sharedInstance().outputVolume >= 0.4
        }
    }

    /// Chooses the built-in mic's bottom, front or back data source. False if iOS does not offer it.
    static func selectMic(_ mic: ComponentID) throws -> Bool {
        let orientation: AVAudioSession.Orientation
        switch mic {
        case .bottomMic: orientation = .bottom
        case .frontMic: orientation = .front
        case .backMic: orientation = .back
        default: return false
        }
        guard let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }),
              let source = builtIn.dataSources?.first(where: { $0.orientation == orientation }) else { return false }
        try builtIn.setPreferredDataSource(source)
        try session.setPreferredInput(builtIn)
        return true
    }

    /// Plays a tone (or silence when `frequency` is nil) and waits for it to finish.
    static func play(frequency: Double?, seconds: Double) async throws {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = engine.outputNode.outputFormat(forBus: 0)
        guard let mono = AVAudioFormat(standardFormatWithSampleRate: format.sampleRate > 0 ? format.sampleRate : 48_000, channels: 1) else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: mono)
        try engine.start()
        defer { engine.stop() }
        start(player, buffer(frequency: frequency, format: mono, seconds: seconds))
        try await Task.sleep(nanoseconds: UInt64((seconds + 0.1) * 1_000_000_000))
    }

    /// Plays a tone (or silence) while recording from the selected mic.
    static func playAndRecord(frequency: Double?, seconds: Double) async throws -> (samples: [Float], sampleRate: Double) {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0,
              let mono = AVAudioFormat(standardFormatWithSampleRate: inputFormat.sampleRate, channels: 1) else {
            throw NSError(domain: "Jungle", code: 1, userInfo: [NSLocalizedDescriptionKey: "No microphone input"])
        }
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: mono)

        let recorder = SampleCollector()
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            recorder.append(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        }
        try engine.start()
        defer {
            input.removeTap(onBus: 0)
            engine.stop()
        }
        start(player, buffer(frequency: frequency, format: mono, seconds: seconds - 0.2))
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        return (recorder.samples, inputFormat.sampleRate)
    }

    /// Synchronous on purpose: we time playback with Task.sleep, not the completion handler.
    private static func start(_ player: AVAudioPlayerNode, _ buffer: AVAudioPCMBuffer) {
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        player.play()
    }

    private static func buffer(frequency: Double?, format: AVAudioFormat, seconds: Double) -> AVAudioPCMBuffer {
        let samples = frequency.map { ToneAnalysis.sine(frequency: $0, sampleRate: format.sampleRate, seconds: seconds) }
            ?? [Float](repeating: 0, count: Int(format.sampleRate * seconds))
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        let channel = buffer.floatChannelData![0]
        for (i, sample) in samples.enumerated() { channel[i] = sample }
        return buffer
    }
}

/// Collects samples from the audio thread.
private final class SampleCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: [Float] = []

    func append(_ samples: UnsafeBufferPointer<Float>) {
        lock.lock()
        buffer.append(contentsOf: samples)
        lock.unlock()
    }

    var samples: [Float] {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
}
#endif
