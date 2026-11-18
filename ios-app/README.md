# JUNGLE: iPhone condition report

ENGR class final project: an iPhone app that runs hardware diagnostics and a cosmetic survey, then produces a PDF condition report a seller can attach to any listing. How the screens talk to the logic is in [docs/CONTRACT.md](docs/CONTRACT.md).

## Layout

```
Jungle.xcodeproj           open this in Xcode
App/                       SwiftUI app target (screens only, no test logic)
  ContentView, Screens/     temporary UI: home, test screen, survey, PDF viewer
  DevTools/                developer options (simulate broken parts, scenarios)
Packages/DiagnosticsCore/  Swift package with all non-UI code, plus unit tests
Config/                    build settings; your signing file goes here
Scripts/check-ios14.sh     checks that no code needs anything newer than iOS 14
docs/                      contract between the screens and the core
```

Add new Swift files from inside Xcode (File > New, with the **Jungle** target ticked), not in Finder. A file dropped into the `App` folder in Finder is not compiled. Adding a file changes `Jungle.xcodeproj/project.pbxproj`, so pull before you add files and commit that change together with the new file.

## First-time setup

1. Use **Xcode 15 or newer**. The app supports iOS 14 and later.
2. Copy `Config/Signing.local.xcconfig.example` to `Config/Signing.local.xcconfig`. Put your personal team ID in it, plus a bundle ID that is unique to you. Git ignores this file.
   - Don't set the team in Xcode's Signing & Capabilities tab. Doing that writes your team into the shared project file. If Xcode changes `project.pbxproj` on its own, don't commit that change.
3. Open `Jungle.xcodeproj`, choose the **Jungle** scheme, select your iPhone, and press Run.
4. On the phone, the first time only: go to Settings > General > VPN & Device Management and trust your developer certificate. Also turn on Developer Mode if the phone asks (iOS 16 and later).

Free-account installs expire after **7 days**. Reinstall on every demo device the day before each event.

## iOS 14

The app must run on iOS 14 (an iPhone 7 Plus and an iPhone 8). Two things follow.

- **Check before you commit:** run `Scripts/check-ios14.sh`. Xcode 16 and newer build this project at iOS 15 and never warn about iOS 15-only code; the script does, on any Mac. It prints `iOS 14 check passed` or the errors.
- **Installing on an iOS 14 phone** needs Xcode 15 (Xcode 16 and newer cannot build below iOS 15). On that Mac only, uncomment `IPHONEOS_DEPLOYMENT_TARGET = 14.0` in your `Config/Signing.local.xcconfig`.

## Running the core tests

```
cd Packages/DiagnosticsCore
swift test
```

These run on the Mac in a few seconds and need no phone. To run them in Xcode instead, open the `Packages/DiagnosticsCore` folder on its own (File > Open) and press Cmd-U. Inside `Jungle.xcodeproj` the package scheme has no test action.
