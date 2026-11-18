import DiagnosticsCore
import SwiftUI

/// The condition survey: four cosmetic ratings, three declarations,
/// an optional IMEI and a notes box. Answers go straight into `survey.answers`.
struct SurveyView: View {
    @EnvironmentObject private var survey: SurveyModel

    var body: some View {
        Form {
            Section(header: Text("How to grade"), footer: Text("Use the same scale for every area.")) {
                ForEach(CosmeticRating.allCases, id: \.self) { rating in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rating.title).font(.subheadline.bold())
                        Text(rating.definition).font(.caption).foregroundColor(.secondary)
                    }
                }
            }

            ForEach(CosmeticArea.allCases, id: \.self) { area in
                Section(header: Text("\(area.title): \(area.covers.lowercased())"),
                        footer: Text(survey.answers[area]?.definition ?? "Choose a rating.")) {
                    Picker(area.title, selection: $survey.answers[area]) {
                        ForEach(CosmeticRating.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }

            Section(header: Text("Battery health"),
                    footer: Text("Find it in Settings > Battery > Battery Health. Apps can't read it.")) {
                HStack {
                    TextField("For example 87", text: batteryText)
                        .keyboardType(.numberPad)
                    Text("%").foregroundColor(.secondary)
                }
            }

            Section(header: Text("Have any parts been replaced?")) {
                Picker("Parts replaced", selection: $survey.answers.partsReplaced) {
                    ForEach(YesNoUnsure.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            Section(header: Text("Is Activation Lock (Find My) turned off?"),
                    footer: Text("A buyer can't use a phone that is still locked to your Apple ID.")) {
                Picker("Activation Lock off", selection: $survey.answers.activationLockOff) {
                    Text("Yes").tag(Optional(true))
                    Text("No").tag(Optional(false))
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            Section(header: Text("IMEI (optional)"),
                    footer: Text("Settings > General > About. Lets a buyer check the report matches the phone.")) {
                TextField("15 digits", text: imeiText)
                    .keyboardType(.numberPad)
            }

            Section(header: Text("Additional notes (optional)")) {
                TextEditor(text: $survey.answers.notes)
                    .frame(minHeight: 100)
            }

            Section {
                if survey.answers.isComplete {
                    Label("Survey complete", systemImage: "checkmark.circle.fill").foregroundColor(.green)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Still to answer").font(.subheadline.bold())
                        Text(survey.answers.missing.joined(separator: ", ")).font(.subheadline).foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Condition survey")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: Keyboard.hide) { Image(systemName: "keyboard.chevron.compact.down") }
                    .accessibilityLabel(Text("Hide keyboard"))
            }
        }
    }

    private var batteryText: Binding<String> {
        Binding(
            get: { survey.answers.batteryHealthPercent.map(String.init) ?? "" },
            set: { survey.answers.batteryHealthPercent = Int($0.filter(\.isNumber).prefix(3)) }
        )
    }

    private var imeiText: Binding<String> {
        Binding(
            get: { survey.answers.imei ?? "" },
            set: {
                let digits = String($0.filter(\.isNumber).prefix(15))
                survey.answers.imei = digits.isEmpty ? nil : digits
            }
        )
    }
}
