import DiagnosticsCore
import SwiftUI

@main
struct JungleApp: App {
    @StateObject private var faults: FaultInjector
    @StateObject private var runner: TestRunner
    @StateObject private var survey = SurveyModel()
    @StateObject private var store = ReportStore()

    init() {
        let faults = FaultInjector()
        _faults = StateObject(wrappedValue: faults)
        _runner = StateObject(wrappedValue: TestRunner(device: DeviceDetector.detect(), faults: faults))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(faults)
                .environmentObject(runner)
                .environmentObject(survey)
                .environmentObject(store)
                .onAppear { try? store.installSamplesIfNeeded() }
        }
    }
}
