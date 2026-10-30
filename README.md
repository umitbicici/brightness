# Brightness

A macOS menu bar app. Its first feature: adjusting the brightness of every connected display from one panel — the built-in display, Apple displays and third-party monitors over DDC/CI. The app is built from feature modules so more features can be added over time.

- Swift 6 and SwiftUI, using only stock system components: `MenuBarExtra` for the menu bar panel, the `Settings` scene for preferences
- macOS 14 or later; Liquid Glass on macOS 26
- English and Turkish, following the system language
- Automatic updates with [Sparkle](https://sparkle-project.org) through GitHub Releases

## Installing

Download the latest `.dmg` from [Releases](https://github.com/umitbicici/brightness/releases/latest) and drag Brightness to Applications. Builds are not notarized yet: on first launch, right-click the app in Finder and choose **Open**. Later versions are installed by the app itself.

## Development

Requirements: Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate          # project.yml → Brightness.xcodeproj (not checked in)
open Brightness.xcodeproj  # or build from the command line:
xcodebuild -scheme Brightness -derivedDataPath build/DerivedData build
xcodebuild -scheme Brightness -derivedDataPath build/DerivedData test
```

Project settings live in `project.yml`; changes made to the generated `.xcodeproj` are lost on the next `xcodegen generate`.

## Structure

```
Brightness/
  App/          Entry point (MenuBarExtra and Settings scenes), shared services
  Core/         Feature protocol, preferences, launch at login, updater
  UI/           Panel content, Settings window, on-screen indicator
  Features/
    Brightness/ Brightness feature: model, views and hardware layer
  Resources/    Info.plist, assets, Localizable.xcstrings
BrightnessTests/  Unit tests (Swift Testing)
```

**Adding a feature:** create a type that conforms to `AppFeature` under `Features/` and add it to `features` in `AppEnvironment`. It gets its own section in the panel and its own page in Settings.

**UI guideline:** use stock SwiftUI and AppKit components only, and follow how macOS itself presents the same thing (System Settings, Control Center). No custom-drawn controls — the app should pick up system design changes on its own.

**Localization:** write UI strings in English in code; translations live in `Resources/Localizable.xcstrings`.

## How brightness is controlled

| Display | Method |
|---|---|
| Built-in display, Apple displays (Studio Display, Pro Display XDR) | DisplayServices — the private framework behind the brightness keys |
| Other external monitors | DDC/CI over I2C through `IOAVService` (Apple Silicon) |

All display commands go through a single worker thread (`BrightnessService`):

- Commands are at least 25 ms apart; some monitors (such as the Samsung Odyssey G5) silently drop commands that arrive sooner.
- While a slider is being dragged, values are written quickly without confirmation, and large jumps are split into small steps.
- When the slider is released, or after 400 ms without changes, the final value is read back from the monitor and written again if it didn't stick.

DDC/CI must be enabled in the monitor's own menu. Some docks, MST hubs and HDMI adapters don't pass DDC/CI through; such displays are listed as "Not responding".

## Releasing

See [RELEASING.md](RELEASING.md).
