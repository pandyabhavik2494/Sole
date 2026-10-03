# Sole

An iOS pedometer that counts steps with the iPhone's motion sensor and syncs both ways with
Apple Health, which is also its backup. SwiftUI, iOS 17+, no third-party code.

Product spec: [docs/sole-spec.md](docs/sole-spec.md). Mockups: [docs/mockups.html](docs/mockups.html).

## Layout

| Folder | What's in it |
| --- | --- |
| `Sole/Model` | SwiftData models (`HourlySteps`, `DailySummary`), the merge and streak rules (`StepMath`), the on-device container |
| `Sole/Services` | `StepEngine` (sensor backfill, live count, Health sync, widget snapshot), `StepStore`, `PedometerService`, `HealthService`, `Preferences` |
| `Sole/Views` | Today, History, Settings, onboarding |
| `SoleWidget` | Home Screen and Lock Screen widgets |
| `Shared` | Code used by both the app and the widget: colours, formatting, the App Group snapshot |
| `SoleTests` | Unit tests for the merge rule, streaks and the store |
| `Config` | Entitlements and Info.plist additions |

## How steps are counted

- Steps are stored per hour per source (`phone`, `health`, `manual`).
- Each hour's total is the **higher** of the iPhone sensor and Apple Health, plus manual entries,
  so carrying an iPhone while wearing an Apple Watch counts once.
- Every launch backfills each hour since the last run from CMPedometer's 7-day history.
- Health is read from every source except Sole (all history on first connect, which is how a
  reinstall or new iPhone gets its history back), and Sole's own completed hours are written back
  with per-hour sync identifiers.

## Building

```sh
xcodebuild -project Sole.xcodeproj -scheme Sole -destination 'platform=iOS Simulator,name=iPhone 17' test
```

The simulator has no step sensor. Launch with `-seedSampleData` to fill 120 days of sample data
(debug builds only), and `-tab history` or `-tab settings` to open on another tab.

## Signing

Signed with team `BPPU7JV4Q4`. Sole uses only HealthKit and an App Group, which a free personal
team supports, so it runs on an iPhone without the paid developer program.
