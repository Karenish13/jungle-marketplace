import DiagnosticsCore
import SwiftUI

/// One test per screen, shown full screen over the home screen while `runner.phase` is not idle.
/// Used for the guided flow and for running a single test from the home list.
struct TestSessionView: View {
    @EnvironmentObject private var runner: TestRunner
    /// True when one test was started from the home list: the result screen offers Done, not Next.
    let singleRun: Bool
    /// After the last test, the survey opens here, inside the same full-screen cover, rather than
    /// being pushed on the home screen (pushing it after the cover closes is unreliable).
    @State private var showingSurvey = false

    var body: some View {
        if showingSurvey {
            NavigationView {
                SurveyView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { runner.close() }
                        }
                    }
            }
            .navigationViewStyle(StackNavigationViewStyle())
        } else {
            session
        }
    }

    @ViewBuilder private var session: some View {
        switch runner.phase {
        case .running(.touchGrid(let grid)):
            TouchGridView(grid: grid, onGiveUp: { runner.finishInteraction() })
        case .running(.colourScreens(let colours, let defect)):
            ColourScreensView(colours: colours, defect: defect, onDone: { runner.finishInteraction() })
        case .running(.multiTouch(let model)):
            MultiTouchView(model: model, onGiveUp: { runner.finishInteraction() })
        case .running(.forcePress(let model)):
            ForcePressView(model: model, onGiveUp: { runner.finishInteraction() })
        default:
            card
        }
    }

    // MARK: - Card layout

    private var card: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                content
                    .frame(maxWidth: .infinity)
                    .padding(24)
            }
            buttons
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Text(headerTitle).font(.subheadline).foregroundColor(.secondary)
                Spacer()
                Button(action: { runner.close() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .accessibilityLabel(Text("Close"))
            }
            if !singleRun, let index = runner.currentIndex {
                ProgressView(value: Double(index), total: Double(max(runner.plan.count, 1)))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var headerTitle: String {
        if case .finished = runner.phase { return "Diagnostics" }
        guard let index = runner.currentIndex else { return "" }
        return singleRun ? "Single test" : "Test \(index + 1) of \(runner.plan.count)"
    }

    // MARK: - Content per phase

    @ViewBuilder private var content: some View {
        switch runner.phase {
        case .idle:
            EmptyView()
        case .ready:
            if let id = runner.currentTest {
                VStack(spacing: 18) {
                    TestIcon(id: id, device: runner.device)
                    Text(id.title(on: runner.device.capabilities)).font(.largeTitle.bold()).multilineTextAlignment(.center)
                    Text(id.instructions).font(.body).multilineTextAlignment(.center).foregroundColor(.secondary)
                    if id == .biometrics, let warning = BiometricSetup.warning(for: runner.device.capabilities) {
                        SimulationBanner(text: warning)
                            .padding()
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(12)
                    }
                }
            }
        case .running(let interaction):
            running(interaction)
        case .showingResult(let result):
            ResultDetail(result: result, caps: runner.device.capabilities)
        case .finished:
            FinishedSummary()
        }
    }

    @ViewBuilder private func running(_ interaction: TestInteraction) -> some View {
        VStack(spacing: 22) {
            if let id = runner.currentTest, !interaction.isCameraPreview { TestIcon(id: id, device: runner.device) }
            switch interaction {
            case .working(let message):
                Text(message).font(.title3).multilineTextAlignment(.center)
                if let p = runner.progress { ProgressView(value: p) } else { ProgressView() }
            case .waitingForAction(let message):
                Text(message).font(.title2.bold()).multilineTextAlignment(.center)
                if let p = runner.progress { ProgressView(value: p) }
            case .yesNo(let question):
                Text(question).font(.title2.bold()).multilineTextAlignment(.center)
            case .cameraPreview(let message, let feed):
                CameraPreview(feed: feed)
                    .frame(height: 360)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(16)
                Text(message).font(.title3).multilineTextAlignment(.center)
                if let p = runner.progress { ProgressView(value: p) }
            case .touchGrid, .colourScreens, .multiTouch, .forcePress:
                ProgressView()
            }
        }
    }

    // MARK: - Buttons per phase

    @ViewBuilder private var buttons: some View {
        VStack(spacing: 10) {
            switch runner.phase {
            case .idle:
                EmptyView()
            case .ready:
                Button("Start") { runner.startCurrentTest() }.buttonStyle(PrimaryButtonStyle())
                Button("Skip this test") { runner.skip() }.buttonStyle(SecondaryButtonStyle())
            case .running(.yesNo):
                Button("Yes") { runner.answer(true) }.buttonStyle(PrimaryButtonStyle())
                Button("No") { runner.answer(false) }.buttonStyle(SecondaryButtonStyle(colour: .red))
                skipLink
            case .running(.waitingForAction):
                Button("Nothing happened") { runner.finishInteraction() }.buttonStyle(SecondaryButtonStyle(colour: .red))
                skipLink
            case .running:
                skipLink
            case .showingResult:
                if singleRun {
                    Button("Done") { runner.close() }.buttonStyle(PrimaryButtonStyle())
                } else {
                    Button(isLastTest ? "Finish" : "Next test") { runner.next() }.buttonStyle(PrimaryButtonStyle())
                }
                Button("Run it again") { runner.retry() }.buttonStyle(SecondaryButtonStyle())
            case .finished:
                Button("Continue to the survey") { showingSurvey = true }.buttonStyle(PrimaryButtonStyle())
                Button("Back to home") { runner.close() }.buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var skipLink: some View {
        Button("Skip this test") { runner.skip() }
            .font(.subheadline)
            .padding(.top, 4)
    }

    private var isLastTest: Bool {
        guard let index = runner.currentIndex else { return false }
        return index == runner.plan.count - 1
    }
}

/// The result of one test: overall status, then each component with its note and measurements.
private struct ResultDetail: View {
    let result: TestResult
    let caps: DeviceCapabilities

    var body: some View {
        VStack(spacing: 20) {
            StatusIcon(status: result.status, size: 64)
            Text(result.status.label).font(.largeTitle.bold()).foregroundColor(result.status.colour)
            if let override = result.override {
                SimulationBanner(text: "Developer override: \(override.label)")
            }
            VStack(spacing: 0) {
                ForEach(result.components, id: \.component) { c in
                    ComponentResultRow(result: c, caps: caps)
                    if c.component != result.components.last?.component { Divider() }
                }
            }
            .padding(.horizontal)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

struct ComponentResultRow: View {
    let result: ComponentResult
    let caps: DeviceCapabilities

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StatusIcon(status: result.status)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.component.displayName(on: caps)).font(.headline)
                    Spacer()
                    Text(result.evidence.label).font(.caption).foregroundColor(.secondary)
                }
                if let note = result.note {
                    Text(note).font(.subheadline).foregroundColor(.secondary)
                }
                ForEach(result.measurements, id: \.self) { m in
                    Text("\(m.name): \(m.value)").font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
    }
}

private struct FinishedSummary: View {
    @EnvironmentObject private var runner: TestRunner

    var body: some View {
        let statuses = runner.orderedResults.map(\.status)
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 64)).foregroundColor(.accentColor)
            Text("Diagnostics done").font(.largeTitle.bold())
            HStack(spacing: 24) {
                count(statuses.filter { $0 == .pass }.count, "passed", .green)
                count(statuses.filter { $0 == .fail }.count, "failed", .red)
                count(statuses.filter { $0 == .notTested }.count, "not tested", .orange)
            }
            Text("Next, answer a few questions about how the phone looks. They go into the report with these results.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }

    private func count(_ n: Int, _ label: String, _ colour: Color) -> some View {
        VStack {
            Text("\(n)").font(.title.bold()).foregroundColor(colour)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
    }
}

/// A large symbol for each test.
struct TestIcon: View {
    let id: TestID
    let device: DeviceProfile

    var body: some View {
        Image(systemName: id.symbol(for: device.capabilities))
            .font(.system(size: 52))
            .foregroundColor(.accentColor)
            .frame(height: 70)
    }
}

extension TestID {
    /// SF Symbols available on iOS 14.
    func symbol(for caps: DeviceCapabilities) -> String {
        switch self {
        case .touchscreen: return "hand.draw"
        case .display: return "rectangle.on.rectangle"
        case .audioLoopback: return "speaker.wave.2"
        case .earpiece: return "ear"
        case .haptics: return "iphone.radiowaves.left.and.right"
        case .rearWideCamera, .rearUltraWideCamera, .rearTelephotoCamera: return "camera"
        case .frontCamera: return "person.crop.square"
        case .motionSensors: return "gyroscope"
        case .volumeButtons: return "speaker.plus"
        case .sideButton: return "lock"
        case .homeButton: return "house"
        case .chargingPort, .wirelessCharging: return "bolt"
        case .biometrics: return caps.biometric == .faceID ? "faceid" : "touchid"
        case .multiTouch, .proximity: return "hand.raised"
        case .forceTouch: return "hand.point.up.left"
        case .ringerControl: return "bell.slash"
        case .flashlight: return "flashlight.on.fill"
        case .depth: return "viewfinder"
        case .wifi: return "wifi"
        case .bluetooth, .cellular: return "antenna.radiowaves.left.and.right"
        case .gps: return "location"
        }
    }
}
