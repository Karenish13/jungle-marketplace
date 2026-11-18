import XCTest
@testable import DiagnosticsCore

final class CatalogTests: XCTestCase {
    func testIPhone7() {
        let model = DeviceCatalog.model(for: "iPhone9,3")!
        XCTAssertEqual(model.name, "iPhone 7")
        XCTAssertTrue(model.capabilities.hasHomeButton)
        XCTAssertTrue(model.capabilities.has3DTouch)
        XCTAssertEqual(model.capabilities.rearCameras, [.rearWideCamera])
    }

    func testIdentifiersAreUnique() {
        let all = DeviceCatalog.models.flatMap(\.identifiers)
        XCTAssertEqual(all.count, Set(all).count)
    }

    func testUnknownFallsBack() {
        XCTAssertNil(DeviceCatalog.model(for: "iPhone99,1"))
        let profile = DeviceDetector.detect(overrideIdentifier: "iPhone99,1")
        XCTAssertFalse(profile.isRecognized)
    }

    func testOverrideKeepsActualIdentifier() {
        let profile = DeviceDetector.detect(overrideIdentifier: "iPhone9,1")
        XCTAssertEqual(profile.modelName, "iPhone 7")
        XCTAssertNotNil(profile.actualModelIdentifier)
    }

    func testMarketedCapacity() {
        XCTAssertEqual(DeviceDetector.marketedCapacityGB(totalBytes: 63_900_000_000), 64)
        XCTAssertEqual(DeviceDetector.marketedCapacityGB(totalBytes: 127_870_000_000), 128)
        XCTAssertEqual(DeviceDetector.marketedCapacityGB(totalBytes: 31_000_000_000), 32)
        XCTAssertEqual(DeviceDetector.marketedCapacityGB(totalBytes: 0), 0) // unreadable
        var profile = DeviceProfile.sampleIPhone7
        profile.storageGB = 0
        XCTAssertEqual(profile.storageDescription, "Unknown")
    }
}

final class PlanTests: XCTestCase {
    func testPlanDiffersBetweenIPhone7And15Pro() {
        let seven = TestPlan.testIDs(for: DeviceCatalog.model(for: "iPhone9,1")!.capabilities)
        let fifteenPro = TestPlan.testIDs(for: DeviceCatalog.model(for: "iPhone16,1")!.capabilities)
        XCTAssertTrue(seven.contains(.homeButton))
        XCTAssertFalse(fifteenPro.contains(.homeButton))
        XCTAssertTrue(seven.allSatisfy { $0.tier == 1 })
    }

    func testTier2LeavesOutMissingHardware() {
        let seven = TestPlan.testIDs(for: DeviceCatalog.model(for: "iPhone9,1")!.capabilities, includeTier2: true)
        XCTAssertTrue(seven.contains(.forceTouch))
        XCTAssertFalse(seven.contains(.depth))
        XCTAssertFalse(seven.contains(.wirelessCharging))
    }

    func testOneCameraTestPerLens() {
        let cameraTests: Set<TestID> = [.rearWideCamera, .rearUltraWideCamera, .rearTelephotoCamera, .frontCamera]
        func cameras(_ id: String) -> [TestID] {
            TestPlan.testIDs(for: DeviceCatalog.model(for: id)!.capabilities).filter(cameraTests.contains)
        }
        XCTAssertEqual(cameras("iPhone9,1"), [.rearWideCamera, .frontCamera])                       // iPhone 7
        XCTAssertEqual(cameras("iPhone9,2"), [.rearWideCamera, .rearTelephotoCamera, .frontCamera]) // 7 Plus
        XCTAssertEqual(cameras("iPhone14,5"), [.rearWideCamera, .rearUltraWideCamera, .frontCamera]) // 13
        XCTAssertEqual(cameras("iPhone14,2"),
                       [.rearWideCamera, .rearUltraWideCamera, .rearTelephotoCamera, .frontCamera]) // 13 Pro
    }

    func testSingleRearCameraIsJustRearCamera() {
        let seven = DeviceCatalog.model(for: "iPhone9,1")!.capabilities       // one rear camera
        let thirteenPro = DeviceCatalog.model(for: "iPhone14,2")!.capabilities
        XCTAssertEqual(TestID.rearWideCamera.title(on: seven), "Rear camera")
        XCTAssertEqual(ComponentID.rearWideCamera.displayName(on: seven), "Rear camera")
        XCTAssertEqual(TestID.rearWideCamera.title(on: thirteenPro), "Rear camera (wide)")
        XCTAssertEqual(ComponentID.rearWideCamera.displayName(on: thirteenPro), "Rear camera (wide)")
        XCTAssertEqual(ComponentID.frontCamera.displayName(on: seven), "Front camera")
    }

    func testHapticsIsInTheMainPlan() {
        let seven = TestPlan.testIDs(for: DeviceCatalog.model(for: "iPhone9,1")!.capabilities)
        XCTAssertTrue(seven.contains(.haptics))
        XCTAssertEqual(TestID.haptics.tier, 1)
    }

    func testQuickDemoSuitsVisitors() {
        let plan = TestPlan.testIDs(for: DeviceCatalog.model(for: "iPhone14,2")!.capabilities, mode: .quickDemo)
        XCTAssertFalse(plan.contains(.biometrics)) // a visitor is not enrolled
        XCTAssertTrue(plan.contains(.motionSensors))
    }

    func testStorageIsNoLongerATest() {
        XCTAssertFalse(TestID.allCases.map(\.rawValue).contains("storage"))
        XCTAssertEqual(DeviceProfile.sampleIPhone7.storageDescription, "32 GB") // still in the report header
    }
}

final class CameraAnalysisTests: XCTestCase {
    private func stats(_ pixels: [UInt8], width: Int, height: Int) -> FrameStats {
        pixels.withUnsafeBufferPointer {
            FrameStats.analyze(luma: $0.baseAddress!, width: width, height: height, bytesPerRow: width, step: 1)
        }
    }

    func testBlackFrameFails() {
        let s = stats([UInt8](repeating: 3, count: 64), width: 8, height: 8)
        XCTAssertEqual(CameraVerdict.evaluate(s).status, .fail)
        XCTAssertEqual(CameraVerdict.evaluate(s).note, "Image was black")
    }

    func testFlatGreyFrameFails() {
        let s = stats([UInt8](repeating: 128, count: 64), width: 8, height: 8)
        XCTAssertEqual(s.stdDev, 0, accuracy: 0.001)
        XCTAssertEqual(CameraVerdict.evaluate(s).note, "Image was one flat colour")
    }

    func testRealisticFramePasses() {
        let pixels = (0..<64).map { UInt8(60 + ($0 * 37) % 120) }
        let s = stats(pixels, width: 8, height: 8)
        XCTAssertEqual(CameraVerdict.evaluate(s).status, .pass)
    }

    func testBlankFaultTurnsGoodFrameBlack() {
        let good = FrameStats(mean: 120, stdDev: 40, width: 640, height: 480)
        XCTAssertEqual(CameraVerdict.evaluate(good).status, .pass)
        XCTAssertEqual(CameraVerdict.evaluate(good.blanked()).status, .fail)
    }
}

@MainActor
final class RunnerTests: XCTestCase {
    /// Asks one yes/no question; passes on yes.
    final class AskTest: DiagnosticTest {
        let id = TestID.earpiece
        let components: [ComponentID] = [.earpiece]
        func run(_ context: TestContext) async throws -> [ComponentResult] {
            let ok = try await context.askYesNo("Did you hear it?")
            return [ComponentResult(.earpiece, ok ? .pass : .fail, evidence: .userConfirmed)]
        }
    }

    private func waitFor(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func isYesNo(_ runner: TestRunner) -> Bool {
        if case .running(.yesNo) = runner.phase { return true }
        return false
    }

    private func grid(_ runner: TestRunner) -> TouchGridModel? {
        if case .running(.touchGrid(let g)) = runner.phase { return g }
        return nil
    }

    private func shownResult(_ runner: TestRunner) -> TestResult? {
        if case .showingResult(let r) = runner.phase { return r }
        return nil
    }

    func testAnswerYesPasses() async {
        let runner = TestRunner(device: .sampleIPhone7, faults: FaultInjector(), tests: [AskTest()])
        runner.begin()
        runner.startCurrentTest()
        await waitFor { isYesNo(runner) }
        runner.answer(true)
        await waitFor { shownResult(runner) != nil }
        XCTAssertEqual(shownResult(runner)?.status, .pass)
        runner.next()
        guard case .finished = runner.phase else { return XCTFail("expected finished") }
    }

    func testSkipWhileWaitingRecordsNotTested() async {
        let runner = TestRunner(device: .sampleIPhone7, faults: FaultInjector(), tests: [AskTest()])
        runner.begin()
        runner.startCurrentTest()
        await waitFor { isYesNo(runner) }
        runner.skip()
        XCTAssertEqual(shownResult(runner)?.status, .notTested)
        // A late answer must not change anything.
        runner.answer(true)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(runner.results[.earpiece]?.status, .notTested)
    }

    func testCloseKeepsResults() async {
        let runner = TestRunner(device: .sampleIPhone7, faults: FaultInjector(), tests: [AskTest()])
        runner.run(.earpiece)
        await waitFor { isYesNo(runner) }
        runner.answer(true)
        await waitFor { shownResult(runner) != nil }
        runner.close()
        guard case .idle = runner.phase else { return XCTFail("expected idle") }
        XCTAssertEqual(runner.results[.earpiece]?.status, .pass)
    }

    func testForceFailOverride() {
        let faults = FaultInjector()
        faults.setOverride(.forceFail, for: .earpiece)
        let runner = TestRunner(device: .sampleIPhone7, faults: faults, tests: [AskTest()])
        runner.begin()
        runner.startCurrentTest()
        XCTAssertEqual(shownResult(runner)?.status, .fail)
        XCTAssertEqual(shownResult(runner)?.override, .forceFail)
    }

    func testTouchDeadZoneFailsTouchscreen() async {
        let faults = FaultInjector()
        faults.apply(.crackedScreen)
        let runner = TestRunner(device: .sampleIPhone7, faults: faults, tests: [TouchscreenTest()])
        runner.begin()
        runner.startCurrentTest()
        await waitFor { grid(runner) != nil }
        guard let grid = grid(runner) else { return XCTFail("expected grid") }
        for row in 0..<grid.rows {
            for col in 0..<grid.columns {
                grid.touch(x: (Double(col) + 0.5) / Double(grid.columns), y: (Double(row) + 0.5) / Double(grid.rows))
            }
        }
        XCTAssertEqual(grid.painted.count, grid.cellCount * 3 / 4)
        runner.finishInteraction()
        await waitFor { shownResult(runner) != nil }
        XCTAssertEqual(shownResult(runner)?.status, .fail)
    }

    func testFullGridPassesAutomatically() async {
        let runner = TestRunner(device: .sampleIPhone7, faults: FaultInjector(), tests: [TouchscreenTest()])
        runner.begin()
        runner.startCurrentTest()
        await waitFor { grid(runner) != nil }
        guard let grid = grid(runner) else { return XCTFail("expected grid") }
        for i in 0..<grid.cellCount {
            grid.touch(x: (Double(i % grid.columns) + 0.5) / Double(grid.columns),
                       y: (Double(i / grid.columns) + 0.5) / Double(grid.rows))
        }
        await waitFor { shownResult(runner) != nil }
        XCTAssertEqual(shownResult(runner)?.status, .pass)
    }

    func testStampSurvivesClearingFaultsAfterTheRun() async {
        let faults = FaultInjector()
        faults.apply(.partsDonor)
        let runner = TestRunner(device: .sampleIPhone7, faults: faults, tests: [AskTest()])
        runner.begin()
        runner.startCurrentTest()
        await waitFor { isYesNo(runner) }
        runner.answer(true)
        await waitFor { shownResult(runner) != nil }

        faults.clearAll()
        let report = runner.makeReport(survey: .sampleHealthy)
        XCTAssertTrue(report.isSimulated)
        XCTAssertEqual(report.simulation?.details, ["Simulated broken: Touchscreen, Loudspeaker, Rear camera (wide)"])

        runner.reset() // results gone, so nothing simulated is left in the report
        XCTAssertFalse(runner.makeReport(survey: .sampleHealthy).isSimulated)
    }

    func testOverrideResultRecordsSimulation() {
        let faults = FaultInjector()
        faults.setOverride(.forceFail, for: .earpiece)
        let runner = TestRunner(device: .sampleIPhone7, faults: faults, tests: [AskTest()])
        runner.begin()
        runner.startCurrentTest()
        faults.clearAll()
        XCTAssertTrue(runner.makeReport(survey: .sampleHealthy).isSimulated)
    }

    func testPretendDeviceIsStamped() {
        let device = DeviceDetector.detect(overrideIdentifier: "iPhone9,1")
        let report = Report.make(device: device, results: [], survey: .sampleHealthy, faults: FaultInjector(), appVersion: "test")
        XCTAssertEqual(report.simulation?.details, ["Pretending to be iPhone 7"])
    }

    func testReportIsStampedWhenFaultsActive() {
        let faults = FaultInjector()
        let runner = TestRunner(device: .sampleIPhone7, faults: faults, tests: [AskTest()])
        XCTAssertFalse(runner.makeReport(survey: .sampleHealthy).isSimulated)
        faults.apply(.partsDonor)
        XCTAssertTrue(runner.makeReport(survey: .sampleHealthy).isSimulated)
    }
}

@MainActor
final class ReportTests: XCTestCase {
    func testJSONRoundTrip() throws {
        let report = Report.samplePartsDonor
        let decoded = try Report.fromJSON(report.jsonData())
        XCTAssertEqual(decoded, report)
    }

    func testGrades() {
        XCTAssertEqual(Report.sampleHealthy.functionalGrade, .allWorking)
        XCTAssertEqual(Report.samplePartsDonor.functionalGrade, .forParts)
        XCTAssertEqual(Report.samplePartsDonor.cosmeticGrade, .poor)
        XCTAssertEqual(Report.sampleHealthy.cosmeticGrade, .good)
    }

    func testIncompleteGrade() {
        func report(_ results: [TestResult], device: DeviceProfile = .sampleIPhone7) -> Report {
            Report(appVersion: "test", device: device, results: results, survey: .sampleHealthy, simulation: nil)
        }
        // Nothing tested must not read as "all working".
        XCTAssertEqual(report([]).functionalGrade, .incomplete)
        // Every tier 1 test passed except one that was skipped.
        var results = Report.sampleHealthy.results
        results[0] = .notTested(results[0].testID, components: results[0].components.map(\.component),
                                evidence: .automated, note: "Skipped")
        XCTAssertEqual(report(results, device: Report.sampleHealthy.device).functionalGrade, .incomplete)
        // A failure outranks "incomplete".
        let failed = TestResult(testID: .touchscreen, components: [ComponentResult(.touchscreen, .fail, evidence: .automated)])
        XCTAssertEqual(report([failed]).functionalGrade, .forParts)
        // Tier 2 not run does not make it incomplete.
        XCTAssertEqual(Report.sampleHealthy.functionalGrade, .allWorking)
    }

    func testBiometricPartsCarryTransferNote() {
        let seven = Report.samplePartsDonor.partGroups
        XCTAssertNotNil(seven.first { $0.part == .homeButton }?.transferNote)
        XCTAssertNil(seven.first { $0.part == .frontCamera }?.transferNote)   // no Face ID on a 7
        XCTAssertNil(seven.first { $0.part == .screenAssembly }?.transferNote)
        let thirteenPro = Report.sampleHealthy.partGroups
        XCTAssertNotNil(thirteenPro.first { $0.part == .frontCamera }?.transferNote)
    }

    func testBatteryHealthIsClamped() {
        var answers = SurveyAnswers(batteryHealthPercent: 140)
        XCTAssertEqual(answers.batteryHealthPercent, 100)
        answers.batteryHealthPercent = -5
        XCTAssertEqual(answers.batteryHealthPercent, 0)
    }

    func testWirelessChargingOnlyOnPhonesThatHaveIt() {
        for model in DeviceCatalog.models {
            let caps = model.capabilities
            let plan = TestPlan.testIDs(for: caps, includeTier2: true)
            XCTAssertEqual(plan.contains(.wirelessCharging), caps.hasWirelessCharging, model.name)
        }
        for name in ["iPhone 6s", "iPhone 6s Plus", "iPhone SE (1st generation)", "iPhone 7", "iPhone 7 Plus"] {
            XCTAssertFalse(DeviceCatalog.models.first { $0.name == name }!.capabilities.hasWirelessCharging, name)
        }
        // The on-screen and PDF component list leaves it out on an iPhone 7.
        XCTAssertFalse(Report.samplePartsDonor.presentComponentRows.contains { $0.component == .wirelessCharging })
        XCTAssertTrue(Report.sampleHealthy.presentComponentRows.contains { $0.component == .wirelessCharging })
    }

    func testRowsCoverEveryComponent() {
        let rows = Report.samplePartsDonor.componentRows
        XCTAssertEqual(rows.count, ComponentID.allCases.count)
        XCTAssertEqual(rows.first { $0.component == .faceID }?.status, .notPresent)
        XCTAssertEqual(rows.first { $0.component == .battery }?.status, .fail) // 71%
        XCTAssertEqual(rows.first { $0.component == .battery }?.evidence, .selfReported)
    }

    func testPartsView() {
        let groups = Report.samplePartsDonor.partGroups
        XCTAssertFalse(groups.first { $0.part == .screenAssembly }!.isHarvestable)
        XCTAssertTrue(groups.first { $0.part == .homeButton }!.isHarvestable)
        XCTAssertNil(groups.first { $0.part == .wirelessChargingCoil }) // iPhone 7 has none
    }

    func testStoreSaveListDelete() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ReportStore(directory: dir)
        XCTAssertTrue(store.reports.isEmpty)
        try store.installSamplesIfNeeded()
        XCTAssertEqual(store.reports.count, 2)
        try store.save(Report.sampleHealthy, pdf: Data("%PDF".utf8))
        XCTAssertNotNil(store.existingPDF(for: Report.sampleHealthy.id))
        try store.delete(Report.sampleHealthy.id)
        XCTAssertEqual(store.reports.map(\.id), [Report.samplePartsDonor.id])
    }

    func testStaleSampleIsReplaced() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ReportStore(directory: dir)
        try store.installSamplesIfNeeded()
        // A sample saved by an older build that no longer decodes (e.g. it had the storage test).
        try Data("{\"old\": true}".utf8).write(to: store.jsonURL(for: Report.sampleHealthy.id))
        try Data("%PDF old".utf8).write(to: store.pdfURL(for: Report.sampleHealthy.id))
        store.reload()
        XCTAssertEqual(store.reports.count, 1)
        try store.installSamplesIfNeeded()
        XCTAssertEqual(store.reports.count, 2)
        XCTAssertNil(store.existingPDF(for: Report.sampleHealthy.id)) // stale PDF removed, re-rendered on open
    }

    func testStoreRendersMissingPDF() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ReportStore(directory: dir)
        try store.installSamplesIfNeeded()                 // samples are saved without a PDF
        XCTAssertNil(store.existingPDF(for: Report.samplePartsDonor.id))
        let url = try store.pdfFile(for: Report.samplePartsDonor)
        XCTAssertEqual(try Data(contentsOf: url).prefix(4), Data("%PDF".utf8))
        XCTAssertNotNil(store.existingPDF(for: Report.samplePartsDonor.id))
    }

    func testSurveyCompleteness() {
        var answers = SurveyAnswers()
        XCTAssertEqual(answers.missing.count, 7)
        answers = .sampleHealthy
        XCTAssertTrue(answers.isComplete)
        answers[.back] = nil
        XCTAssertEqual(answers.missing, ["Back"])
    }
}

final class DetectionLogicTests: XCTestCase {
    func testToneDetectedInCleanRecording() {
        let tone = ToneAnalysis.sine(frequency: 2000, sampleRate: 48_000, seconds: 0.5)
        XCTAssertTrue(ToneAnalysis.containsTone(tone, sampleRate: 48_000))
    }

    func testToneDetectedUnderNoise() {
        var rng = SystemRandomNumberGenerator()
        let tone = ToneAnalysis.sine(frequency: 2000, sampleRate: 48_000, seconds: 0.5, amplitude: 0.2)
        let noisy = tone.map { $0 + Float.random(in: -0.3...0.3, using: &rng) }
        XCTAssertTrue(ToneAnalysis.containsTone(noisy, sampleRate: 48_000))
    }

    func testSilenceAndNoiseHaveNoTone() {
        XCTAssertFalse(ToneAnalysis.containsTone([Float](repeating: 0, count: 24_000), sampleRate: 48_000))
        let noise = (0..<24_000).map { _ in Float.random(in: -0.5...0.5) }
        XCTAssertFalse(ToneAnalysis.containsTone(noise, sampleRate: 48_000))
        let wrongTone = ToneAnalysis.sine(frequency: 500, sampleRate: 48_000, seconds: 0.5)
        XCTAssertFalse(ToneAnalysis.containsTone(wrongTone, sampleRate: 48_000))
    }

    func testMotionVerdicts() {
        let still = [Vector3](repeating: Vector3(0, 0, -1), count: 100)
        let tilted = (0..<100).map { i in Vector3(sin(Double(i) / 30), 0, -cos(Double(i) / 30)) }
        XCTAssertEqual(MotionVerdict.accelerometer([]).0, .fail)
        XCTAssertEqual(MotionVerdict.accelerometer(still).0, .fail)
        XCTAssertEqual(MotionVerdict.accelerometer(tilted).0, .pass)
        XCTAssertEqual(MotionVerdict.gyroscope([Vector3(0, 1.2, 0)]).0, .pass)
        XCTAssertEqual(MotionVerdict.gyroscope([Vector3(0, 0.05, 0)]).0, .fail)
        XCTAssertEqual(MotionVerdict.compass([Vector3(20, 0, -40), Vector3(-15, 10, -40)]).0, .pass)
        XCTAssertEqual(MotionVerdict.barometer([101.3]).0, .pass)
        XCTAssertEqual(MotionVerdict.barometer([]).0, .fail)
    }

    func testFlashlightAndDepthVerdicts() {
        let off = FrameStats(mean: 60, stdDev: 10, width: 1, height: 1)
        XCTAssertEqual(FlashlightVerdict.evaluate(off: off, on: FrameStats(mean: 110, stdDev: 10, width: 1, height: 1)).status, .pass)
        XCTAssertEqual(FlashlightVerdict.evaluate(off: off, on: off).status, .fail)
        XCTAssertEqual(DepthVerdict.evaluate(validShare: nil).0, .fail)
        XCTAssertEqual(DepthVerdict.evaluate(validShare: DepthVerdict.validShare([0.5, 1.2, 3, 0])).0, .pass)
    }
}

@MainActor
final class SimulatedFaultTests: XCTestCase {
    func testBiometricNonMatchIsNotAFail() {
        XCTAssertEqual(BiometricTest.result(for: .noMatch, component: .faceID).status, .notTested)
        XCTAssertEqual(BiometricTest.result(for: .unavailable, component: .faceID).status, .fail)
        XCTAssertEqual(BiometricTest.result(for: .success, component: .touchID).status, .pass)
    }

    func testBrokenMultiTouchCapsAtOne() {
        let model = TouchCountModel(cap: 1)
        model.update(touchCount: 4)
        XCTAssertFalse(model.isComplete)
        let healthy = TouchCountModel()
        healthy.update(touchCount: 3)
        XCTAssertTrue(healthy.isComplete)
    }

    func testBrokenForceSensorReadsZero() {
        let dead = ForcePressModel(dead: true)
        dead.update(force: 6, maximumForce: 6.6)
        XCTAssertEqual(dead.peak, 0)
        let healthy = ForcePressModel()
        healthy.update(force: 6, maximumForce: 6.6)
        XCTAssertTrue(healthy.isComplete)
    }

    func testBrokenComponentsStampReport() {
        let faults = FaultInjector()
        faults.setBroken(.loudspeaker, true)
        faults.setBroken(.rearWideCamera, true)
        XCTAssertTrue(faults.isActive)
        XCTAssertEqual(faults.activeDescriptions, ["Simulated broken: Loudspeaker, Rear camera (wide)"])
        faults.setBroken(.loudspeaker, false)
        faults.setBroken(.rearWideCamera, false)
        XCTAssertFalse(faults.isActive)
    }

    func testEveryPlannedTestHasARealImplementation() {
        let caps = DeviceCatalog.model(for: "iPhone16,1")!.capabilities
        for id in TestPlan.testIDs(for: caps, includeTier2: true) {
            let test = TestPlan.makeTest(id, caps: caps)
            XCTAssertEqual(test.id, id)
            XCTAssertEqual(test.components, id.components(for: caps), "\(id)")
        }
    }

    /// Tests that do not use hardware can be run end to end with a simulated fault.
    func testBrokenDisplayShowsDefect() async {
        let faults = FaultInjector()
        faults.setBroken(.display, true)
        let runner = TestRunner(device: .sampleIPhone7, faults: faults, tests: [DisplayTest()])
        runner.begin()
        runner.startCurrentTest()
        for _ in 0..<100 {
            if case .running(.colourScreens) = runner.phase { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        guard case .running(.colourScreens(_, let defect)) = runner.phase else { return XCTFail("expected colour screens") }
        XCTAssertEqual(defect, .deadColumn)
    }
}

#if canImport(PDFKit)
import PDFKit

@MainActor
final class PDFTests: XCTestCase {
    private func document(_ report: Report) throws -> PDFDocument {
        let data = ReportPDFBuilder.render(report)
        return try XCTUnwrap(PDFDocument(data: data), "not a readable PDF")
    }

    private func text(_ doc: PDFDocument) -> String { doc.string ?? "" }

    func testRendersReadablePDFWithKeyFacts() throws {
        let report = Report.samplePartsDonor
        let doc = try document(report)
        XCTAssertGreaterThanOrEqual(doc.pageCount, 1)
        let all = text(doc)
        for expected in [report.id, "iPhone 7", "For parts or repair", "Touchscreen", "Parts for repair",
                         "Dropped. Screen cracked", "How to read this report"] {
            XCTAssertTrue(all.contains(expected), "missing \(expected)")
        }
    }

    func testSimulatedStampOnEveryPage() throws {
        let doc = try document(.samplePartsDonor)
        for i in 0..<doc.pageCount {
            let page = doc.page(at: i)?.string ?? ""
            XCTAssertTrue(page.uppercased().contains(SimulationStamp.label.uppercased()), "page \(i + 1) has no stamp")
            XCTAssertTrue(page.contains("Page \(i + 1) of \(doc.pageCount)"))
        }
    }

    func testRealReportHasNoStamp() throws {
        var report = Report.sampleHealthy
        report.simulation = nil
        XCTAssertFalse(text(try document(report)).uppercased().contains(SimulationStamp.label.uppercased()))
    }

    func testOnlyComponentsTheModelHas() throws {
        let seven = text(try document(.samplePartsDonor))       // iPhone 7: no wireless charging, LiDAR or Face ID
        XCTAssertFalse(seven.contains("Wireless charging"))
        XCTAssertFalse(seven.contains("LiDAR"))
        XCTAssertFalse(seven.contains("Face ID"))
        XCTAssertTrue(seven.contains("Rear camera"))
        let thirteenPro = text(try document(.sampleHealthy))
        XCTAssertTrue(thirteenPro.contains("Wireless charging"))
    }

    func testLongReportPaginates() throws {
        var report = Report.samplePartsDonor
        report.survey.notes = String(repeating: "A long note about the phone. ", count: 300)
        XCTAssertGreaterThan(try document(report).pageCount, try document(.samplePartsDonor).pageCount)
    }
}
#endif
