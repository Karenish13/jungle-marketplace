# Core-to-UI contract

This is how the SwiftUI screens (UI) talk to `DiagnosticsCore` (core logic).

**The rule:** screens show state and pass user input back. They never decide whether a test passed. If a screen needs something the core doesn't publish, ask for it; don't work it out in the view.

## The objects

`JungleApp` creates four objects and puts them in the environment. Read them with `@EnvironmentObject`.

| Object | What it is | Screens that use it |
|---|---|---|
| `TestRunner` | The device, the test plan, the running test, and the results | Device confirmation, test screens, results summary |
| `SurveyModel` | The survey answers | Survey screens |
| `ReportStore` | Saved reports on disk | Report list, report viewer |
| `FaultInjector` | Developer options | Developer options screen |

Everything is `ObservableObject` with `@Published` properties, because the app supports iOS 14. Use `NavigationView`, not `NavigationStack`.

**iOS 14 rule:** nothing in a screen may need iOS 15 or newer unless it sits inside `if #available(iOS 15, *)` with an iOS 14 fallback. Xcode will not warn you, so run `Scripts/check-ios14.sh` before committing. Avoid (without that fallback): `.task`, `AsyncImage`, `.swipeActions`, `.refreshable`, `.searchable`, `.confirmationDialog`, `.safeAreaInset`, `@FocusState`, `.bordered` / `.borderedProminent`, `Button(role:)`, `.tint`, `Section("Title")`, `.overlay { }` and `.background { }` with a trailing closure, materials, `.textSelection`, `.formatted()` on dates and numbers, `AttributedString`, async `URLSession` calls. Use instead: `.onAppear`, `Section(header: Text("Title"))`, `.overlay(view)`, `.accentColor`, `.alert` or `.actionSheet`, `DateFormatter`. For a filled button, use `PrimaryButtonStyle` / `SecondaryButtonStyle` from `App/Screens/Styles.swift` or write your own `ButtonStyle`; `.bordered` and `.borderedProminent` are iOS 15.

## Device confirmation

- `runner.device` is a `DeviceProfile`. It has `modelName`, `storageDescription`, `osVersion`, `colour` (the user picks it; the app can't read it) and `isRecognized`.
- When `isRecognized` is false, the model wasn't in the catalog and its capabilities are a guess. Tell the user.
- `runner.plan` is the ordered list of `TestID`s for this phone. Give a test's name with `.title(on: runner.device.capabilities)`, and its instructions with `.instructions`. Name components with `.displayName(on: caps)` (use `report.device.capabilities` in a report). Both call the rear camera just "Rear camera" on a phone that has only one.

## Permissions

Call `await Permissions.requestAll()` from onboarding, before the first test, with a line explaining why the app is about to ask. It asks for camera, microphone, Motion & Fitness, Bluetooth and location one after another, and skips anything already answered. Without it, some prompts appear in the middle of a timed test. The tests still cope if a permission is denied (the result is "not tested").

## Test screens

Switch on `runner.phase`:

```swift
switch runner.phase {
case .idle:                     // nothing started: call runner.begin()
case .ready:                    // show runner.currentTest's title and instructions, Start and Skip
case .running(let interaction): // see the next table
case .showingResult(let r):     // r.status, r.components; Next and Retry
case .finished:                 // every test has a result: go to the survey
}
```

`runner.close()` leaves the test screen at any point: it stops a running test without recording it and goes back to `.idle`, keeping the results so far. The temporary UI shows the test screen as a full-screen cover whenever the phase is not `.idle`, and closes it with `close()`. On `.finished`, its "Continue to the survey" button shows the survey inside that same cover, with a Done button that calls `close()`.

SwiftUI pitfall (iOS 14 and later): don't open a screen from code with `NavigationLink(isActive:)` when the link sits in a `List` row. The list only builds the rows on screen, so if that row is scrolled out of sight nothing opens, the binding stays `true`, and later taps on the row do nothing. This is how "Continue to the survey" broke on 16 Nov. Use a plain `NavigationLink(destination:)` for rows, and present screens opened from code another way (as above, or with `.sheet`).

Before the Face ID / Touch ID test, show `BiometricSetup.warning(for: runner.device.capabilities)` on the `.ready` screen when it is not nil. It says when Face ID or Touch ID is not set up, so the user can skip instead of getting "not tested". The test's `instructions` also say it must be set up first.

Use `runner.currentIndex` and `runner.plan.count` for "Test 3 of 12". `runner.progress` is a 0 to 1 value, or nil for a spinner.

| `TestInteraction` | Show | Call back |
|---|---|---|
| `.working(message)` | The message and a spinner or progress bar | `skip()` |
| `.waitingForAction(message)` | The message, large, e.g. "Press volume up". The core detects the press itself. `progress` counts down the time left | A "Nothing happened" button calls `finishInteraction()` and records a fail; `skip()` records not tested |
| `.yesNo(question)` | The question, plus Yes and No buttons | `answer(true)` / `answer(false)`, or `skip()` |
| `.touchGrid(model)` | A full-screen grid of `model.columns` by `model.rows` cells. Colour each cell where `model.isPainted(row:column:)` is true. Send every drag location to `model.touch(at:in:)`. The test ends by itself once the grid is full | A "Can't fill the rest" button calls `finishInteraction()` |
| `.colourScreens(colours, defect:)` | Each colour full screen (`colour.rgb`), moving to the next on tap. If `defect` is not nil, draw it on top of every colour: a rectangle at `defect.rect` (unit coordinates) in `defect.rgb`. That is a simulated fault | `finishInteraction()` after the last colour |
| `.multiTouch(model)` | Full screen. Show "Put `model.required` fingers on the screen" and `model.current`. Needs a UIKit view with `isMultipleTouchEnabled`; report the number of fingers down with `model.update(touchCount:)` on every touch event. Ends by itself | "Can't do it" calls `finishInteraction()` |
| `.forcePress(model)` | Full screen. "Press hard", with `model.peak` (0 to 1) as a meter. Report `UITouch.force` and `maximumPossibleForce` with `model.update(force:maximumForce:)`. Ends by itself | "Can't do it" calls `finishInteraction()` |
| `.cameraPreview(message, feed)` | A live preview of the camera being tested (an `AVCaptureVideoPreviewLayer` on `feed.session`), the message, and `progress`. If `feed.isBlanked`, show black instead: that camera is simulated as broken. `CameraPreview` in `App/Screens/InteractionViews.swift` does this | `skip()` |

`App/Screens/InteractionViews.swift` has a UIKit `TouchReporter` view that does the multi-touch and force reporting; copy it.

Some tests leave the app on purpose (side button, home button) and continue when the user comes back. Don't reset the flow when the app returns to the foreground.

Buttons: `begin()`, `startCurrentTest()`, `skip()`, `retry()`, `next()`. All of them are safe to call at any time; when a call doesn't apply to the current phase, it does nothing.

Notes for the touch grid: observe the grid model directly (`@ObservedObject var grid: TouchGridModel`). Make the grid cover the whole screen (`.ignoresSafeArea()`). Never block touches with an overlay: if a button sits on top of the grid, attach the drag gesture with `.simultaneousGesture`. `TouchGridView` in `App/Screens/InteractionViews.swift` shows one way to do this.

## Results summary

- `runner.orderedResults` gives a `[TestResult]` in plan order.
- Each `TestResult` has `components: [ComponentResult]`, and each component result has `status` (pass, fail, not tested, not present), `evidence` (automated, user-confirmed, self-reported) and an optional `note`.
- Every enum has `.label` or `.title` text. Use it rather than writing your own strings.

## Survey

Bind controls straight to `survey.answers`:

```swift
Picker("Screen", selection: $survey.answers.screen) {
    ForEach(CosmeticRating.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
}
```

- Loop over `CosmeticArea.allCases` and use `survey.answers[area]` to build the four cosmetic questions from one view.
- Show `rating.definition` under each question, so sellers grade the same way.
- The declarations are `batteryHealthPercent`, `partsReplaced` (Yes / No / Not sure), `activationLockOff`, and `imei` (optional). There is one free-text box, `notes`.
- `survey.answers.missing` lists the unanswered questions. `isComplete` gates the Continue button.

## Report

- `let report = runner.makeReport(survey: survey.answers)`, then `try store.saveWithPDF(report)`. That renders the PDF with `ReportPDFBuilder.render(report)` and saves both the JSON and the PDF. To show a saved report, `try store.pdfFile(for: report)` returns the PDF's file URL and renders it first if it is missing (the preloaded samples have none until first opened). Show it with PDFKit's `PDFView`; share it with `UIActivityViewController` (`ShareLink` is iOS 16). `ReportViewer` in `App/Screens/ReportViews.swift` does both.
- `store.reports` is the saved list, newest first. `store.existingPDF(for: report.id)` returns the PDF's file URL; show it with PDFKit and share it with a share sheet.
- For the summary: `report.functionalGrade.title`, `report.cosmeticGrade?.title`, `report.presentComponentRows` (only what this model has, so for example wireless charging never appears on an iPhone 7; `componentRows` also has the "not present" ones) and `report.partGroups` (the parts view, with an `isHarvestable` flag on each part).
- `functionalGrade` is one of `allWorking`, `incomplete` (no failures, but a tier 1 test for this phone was skipped or not run, e.g. in the quick demo), `minorFaults` and `forParts`.
- In the parts view, show `group.transferNote` under a part when it is not nil. It warns that Touch ID or Face ID is paired to the original phone and stops working after a transfer.
- `report.isSimulated` is true when developer options were on while any test ran, or when the report was built. Show `SimulationStamp.label` ("Demo: simulated results") wherever the report appears. The stamp can't be turned off, and turning the options off after a run doesn't remove it.
- `Report.sampleHealthy` and `Report.samplePartsDonor` are ready-made sample reports for SwiftUI previews. They are also preloaded into the store, so the report list is never empty.

## Developer options screen

- **Simulate a broken part:** `faults.setBroken(.loudspeaker, true)`, and read it back with `faults.isBroken(_:)`. The test still runs normally, but it gets bad input: a camera frame comes back black, the speaker plays silence, a button press is ignored, and so on. The audience sees the app catch the fault. List the switches per test with `test.components(for: runner.device.capabilities)`.
- `faults.setOverride(.forceNotTested, for: .gps)` skips a test without running it (`.forceFail` also exists). Read it back with `faults.override(for:)`. Use this sparingly; simulating a broken part is the better demo.
- `faults.apply(.partsDonor)` loads a scenario, which sets a group of broken parts. `faults.clearAll()` clears everything.
- `faults.forceUserConfirmedAudio = true` makes the audio test ask "did you hear it?" instead of measuring. Use it for a noisy expo.
- `faults.deviceOverride = "iPhone9,1"` pretends to be another phone. Then call `runner.configure(device: DeviceDetector.detect(overrideIdentifier: faults.deviceOverride))`.
- `runner.configure(mode: .quickDemo)` switches to the two-minute expo plan. `runner.configure(includeTier2: true)` adds the tier 2 tests.
- "Reset for next visitor" calls `runner.reset()` and `survey.reset()`.
- Each `TestResult` records the options that were active when it ran in `simulation`. The report stamp is built from those, so you don't need to track it.
- `faults.activeDescriptions` lists what is switched on, ready to display.

## Previews

```swift
struct SummaryView_Previews: PreviewProvider {
    static var previews: some View { SummaryView(report: .samplePartsDonor) }
}
```

To preview a screen that uses the runner, build one with `TestRunner(device: .sampleIPhone7, faults: FaultInjector())`.

## What exists today

| Piece | State |
|---|---|
| Device catalog and detection, test plan, runner, developer options, scenarios | Done, unit tested |
| Report data, grades, parts view, report store, sample reports | Done, unit tested |
| `Permissions.requestAll()` | Done; needs checking on a phone |
| Every test, tier 1 and tier 2 | Written for real, with each test's "simulate broken" behaviour. The pass/fail rules (tone detection, motion, flashlight, LiDAR, camera) are unit tested. The hardware code compiles but has **not yet been run on a real iPhone**, and the Simulator has none of the hardware |
| PDF builder, viewer and sharing | Done; the PDF content is unit tested on the Mac. Not yet opened or shared on a phone |

The temporary UI is a working example of every screen, and it is what the team demo uses until the real screens land:

| File | What it is |
|---|---|
| `App/ContentView.swift` | Home: device, the test list (tap one to run it alone), "Start diagnostics", survey, report, and Developer options at the bottom |
| `App/Screens/TestSessionView.swift` | One test per screen for every phase and interaction, then the survey after the last test |
| `App/Screens/InteractionViews.swift` | Touch grid, colour screens, multi-touch, 3D Touch, `TouchReporter` |
| `App/Screens/SurveyView.swift` | The condition survey |
| `App/Screens/ReportViews.swift` | The PDF viewer with a share button, and the saved reports list |
| `App/DevTools/DeveloperOptionsView.swift` | Simulate broken parts, scenarios, test plan switches, tools |
| `App/Screens/Styles.swift` | Shared button styles and status colours, all iOS 14 safe |
