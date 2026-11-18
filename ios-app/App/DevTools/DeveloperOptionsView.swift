import DiagnosticsCore
import SwiftUI

/// Developer options: simulate broken parts, scenarios, test plan
/// switches and debugging tools. Reached from the bottom of the home screen.
/// Anything switched on here stamps reports "Demo: simulated results".
struct DeveloperOptionsView: View {
    @EnvironmentObject private var runner: TestRunner
    @EnvironmentObject private var faults: FaultInjector
    @EnvironmentObject private var survey: SurveyModel
    @State private var reportJSON: String?

    var body: some View {
        List {
            if faults.isActive {
                Section(header: Text("Active")) {
                    ForEach(faults.activeDescriptions, id: \.self) { SimulationBanner(text: $0) }
                    Button("Clear all developer options") {
                        faults.clearAll()
                        runner.configure(device: DeviceDetector.detect())
                    }
                    .foregroundColor(.red)
                }
            }

            Section(header: Text("Scenarios"), footer: Text("A scenario marks a set of parts as broken and fills in a matching survey.")) {
                ForEach(FaultScenario.allCases, id: \.self) { scenario in
                    Button(scenario.title) {
                        faults.apply(scenario)
                        survey.answers = scenario.sampleSurvey
                    }
                }
            }

            Section(header: Text("Test plan")) {
                Picker("Pretend to be", selection: deviceOverrideBinding) {
                    Text("This phone").tag("")
                    ForEach(DeviceCatalog.models, id: \.name) { model in
                        Text(model.name).tag(model.identifiers[0])
                    }
                }
                Toggle("Include tier 2 tests", isOn: Binding(
                    get: { runner.includeTier2 },
                    set: { runner.configure(includeTier2: $0) }
                ))
                Toggle("Quick demo (short plan)", isOn: Binding(
                    get: { runner.mode == .quickDemo },
                    set: { runner.configure(mode: $0 ? .quickDemo : .full) }
                ))
                Toggle("Audio: ask instead of measuring", isOn: $faults.forceUserConfirmedAudio)
            }

            Section(header: Text("Simulate broken parts"),
                    footer: Text("The test still runs, but gets bad input: a black camera frame, a silent speaker, an ignored button press, and so on.")) {
                ForEach(runner.plan, id: \.self) { test in
                    ForEach(test.components(for: runner.device.capabilities), id: \.self) { component in
                        Toggle(component.displayName(on: runner.device.capabilities), isOn: Binding(
                            get: { faults.isBroken(component) },
                            set: { faults.setBroken(component, $0) }
                        ))
                    }
                }
            }

            Section(header: Text("Tools")) {
                Button("Ask for all permissions now") { Task { await Permissions.requestAll() } }
                Button("Fill the survey with sample answers") { survey.fillWithSampleData() }
                Button("Show report data (JSON)") {
                    let report = runner.makeReport(survey: survey.answers)
                    reportJSON = (try? report.jsonData()).flatMap { String(data: $0, encoding: .utf8) }
                }
                Button("Reset for next visitor") {
                    runner.reset()
                    survey.reset()
                }
                .foregroundColor(.red)
            }

            Section(header: Text("This phone")) {
                row("Identifier", runner.device.modelIdentifier)
                row("Biometric", runner.device.capabilities.biometric.rawValue)
                row("Port", runner.device.capabilities.port.displayName)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Developer options")
        .sheet(isPresented: Binding(get: { reportJSON != nil }, set: { if !$0 { reportJSON = nil } })) {
            ScrollView {
                Text(reportJSON ?? "")
                    .font(.system(.caption2, design: .monospaced))
                    .padding()
            }
        }
    }

    private var deviceOverrideBinding: Binding<String> {
        Binding(get: { faults.deviceOverride ?? "" }, set: { id in
            faults.deviceOverride = id.isEmpty ? nil : id
            runner.configure(device: DeviceDetector.detect(overrideIdentifier: faults.deviceOverride))
        })
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
    }
}
