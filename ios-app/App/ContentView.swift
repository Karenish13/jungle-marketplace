import DiagnosticsCore
import SwiftUI

/// Home screen of the temporary UI: device, tests, survey, report, and the developer options
/// at the very bottom. The real UI from the UI developer replaces this; keep a way into
/// `DeveloperOptionsView` when it does.
struct ContentView: View {
    @EnvironmentObject private var runner: TestRunner
    @EnvironmentObject private var faults: FaultInjector
    @EnvironmentObject private var survey: SurveyModel
    @EnvironmentObject private var store: ReportStore

    @State private var singleRun = false
    @State private var shownReport: Report?

    var body: some View {
        NavigationView {
            List {
                deviceSection
                testsSection
                surveySection
                reportSection
                Section {
                    NavigationLink(destination: DeveloperOptionsView()) {
                        Label("Developer options", systemImage: "wrench.and.screwdriver")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("JUNGLE")
            .fullScreenCover(isPresented: sessionBinding) {
                TestSessionView(singleRun: singleRun)
                    .environmentObject(runner)
                    .environmentObject(survey)
            }
            .sheet(item: $shownReport) { report in
                NavigationView {
                    ReportViewer(report: report)
                        .environmentObject(store)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Done") { shownReport = nil } }
                        }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Sections

    private var deviceSection: some View {
        Section(footer: Text("Repair • Reuse • Reduce")) {
            HStack(spacing: 14) {
                Image(systemName: runner.device.capabilities.hasHomeButton ? "iphone.homebutton" : "iphone")
                    .font(.system(size: 34))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(runner.device.modelName).font(.title3.bold())
                    Text("iOS \(runner.device.osVersion) · \(runner.device.storageDescription)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 6)
            if !runner.device.isRecognized {
                SimulationBanner(text: "This model isn't in the catalog, so the test list is a best guess.")
            }
            if faults.isActive {
                SimulationBanner(text: "Developer options are on. Reports will be stamped \"\(SimulationStamp.label)\".")
            }
        }
    }

    private var testsSection: some View {
        Section(header: Text("Diagnostics"), footer: Text("Tap a test to run it on its own.")) {
            VStack(alignment: .leading, spacing: 10) {
                Button(runner.results.isEmpty ? "Start diagnostics" : "Start again from the beginning", action: startGuided)
                    .buttonStyle(PrimaryButtonStyle())
                Text(progressSummary).font(.footnote).foregroundColor(.secondary)
            }
            .padding(.vertical, 6)

            ForEach(runner.plan, id: \.self) { id in
                Button(action: { runSingle(id) }) {
                    HStack(spacing: 12) {
                        StatusIcon(status: runner.results[id]?.status)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(id.title(on: runner.device.capabilities)).foregroundColor(.primary)
                            if let detail = detail(for: id) {
                                Text(detail).font(.caption).foregroundColor(.secondary).lineLimit(2)
                            }
                        }
                        Spacer()
                        Image(systemName: "play.circle").foregroundColor(.accentColor)
                    }
                }
            }
        }
    }

    private var surveySection: some View {
        Section(header: Text("Condition survey")) {
            // A plain link: an `isActive` link in a List breaks when its row is scrolled off
            // screen (the List has not built it), and then the row stops responding.
            NavigationLink(destination: SurveyView()) {
                HStack {
                    Label("Survey", systemImage: "doc.text")
                    Spacer()
                    Text(surveyStatus).font(.subheadline).foregroundColor(survey.answers.isComplete ? .green : .secondary)
                }
            }
        }
    }

    private var reportSection: some View {
        Section(header: Text("Report"), footer: Text("Creates the PDF condition report from the test results and the survey. Share it from the viewer.")) {
            Button(action: createReport) {
                Label("Create report", systemImage: "doc.richtext")
            }
            NavigationLink(destination: SavedReportsView()) {
                HStack {
                    Label("Saved reports", systemImage: "folder")
                    Spacer()
                    Text("\(store.reports.count)").foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private func startGuided() {
        singleRun = false
        Task {
            // Ask for every permission first, so no prompt interrupts a timed test.
            await Permissions.requestAll()
            runner.begin()
        }
    }

    private func runSingle(_ id: TestID) {
        singleRun = true
        runner.run(id)
    }

    private func createReport() {
        let report = runner.makeReport(survey: survey.answers)
        _ = try? store.saveWithPDF(report)
        shownReport = report
    }

    // MARK: - Derived text

    private var sessionBinding: Binding<Bool> {
        Binding(get: {
            if case .idle = runner.phase { return false }
            return true
        }, set: { shown in
            if !shown { runner.close() }
        })
    }

    private var progressSummary: String {
        let statuses = runner.orderedResults.map(\.status)
        let remaining = runner.plan.count - statuses.count
        if statuses.isEmpty { return "\(runner.plan.count) tests for this phone, about 10 minutes." }
        var parts = ["\(statuses.filter { $0 == .pass }.count) passed",
                     "\(statuses.filter { $0 == .fail }.count) failed"]
        let notTested = statuses.filter { $0 == .notTested }.count
        if notTested > 0 { parts.append("\(notTested) not tested") }
        if remaining > 0 { parts.append("\(remaining) not run") }
        return parts.joined(separator: " · ")
    }

    /// The first note worth showing under a test's name.
    private func detail(for id: TestID) -> String? {
        guard let result = runner.results[id] else { return nil }
        let notable = result.components.first { $0.status == .fail }
            ?? result.components.first { $0.status == .notTested }
        guard let component = notable else { return result.status.label }
        let name = result.components.count > 1 ? "\(component.component.displayName(on: runner.device.capabilities)): " : ""
        return name + (component.note ?? component.status.label)
    }

    private var surveyStatus: String {
        if survey.answers.isComplete { return "Complete" }
        let total = CosmeticArea.allCases.count + 3
        return "\(total - survey.answers.missing.count) of \(total) answered"
    }
}
