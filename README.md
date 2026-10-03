# Sole

An iOS pedometer that counts steps with the iPhone's motion sensor, keeps history in the user's
private iCloud, and syncs both ways with Apple Health. SwiftUI, iOS 17+, no third-party code.

Product spec: [docs/sole-spec.md](docs/sole-spec.md). Mockups: [docs/mockups.html](docs/mockups.html).

## Layout

| Folder | What's in it |
| --- | --- |
| `Sole/Model` | SwiftData models (`HourlySteps`, `DailySummary`), the merge and streak rules (`StepMath`), the CloudKit-backed container |
| `Sole/Services` | `StepEngine` (sensor backfill, live count, Health sync, widget snapshot), `StepStore`, `PedometerService`, `HealthService`, `CloudSyncMonitor`, `Preferences` |
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
- Health is read from every source except Sole (a year back on first connect), and Sole's own
  completed hours are written back with per-hour sync identifiers.

## Building

```sh
xcodebuild -project Sole.xcodeproj -scheme Sole -destination 'platform=iOS Simulator,name=iPhone 17' test
```

The simulator has no step sensor. Launch with `-seedSampleData` to fill 120 days of sample data
(debug builds only), and `-tab history` or `-tab settings` to open on another tab.

## Signing and iCloud

The project is signed with team `BPPU7JV4Q4`, which is currently a free personal team. Personal
teams can't use iCloud or push notifications, so the **Debug** configuration uses
`Config/Sole-PersonalTeam.entitlements` (HealthKit and the App Group only). Debug builds run on an
iPhone today and keep history on the device only.

Once the team is on the paid Apple Developer Program, set the Sole target's Debug
`CODE_SIGN_ENTITLEMENTS` back to `Config/Sole.entitlements` to turn on iCloud sync. Release already
uses it.
