# Sole: product and design spec (v1 proposal)

Status: proposal, nothing built yet (2026-10-03). Visual mockups: docs/mockups.html (open in a browser).

## Core requirements (from Bhavik)
1. Count steps accurately.
2. Use the iPhone's own sensors to count.
3. Store steps in iCloud so they are always available.
4. Two-way sync with Apple Health.

## How each requirement is met

### iPhone sensors and accuracy
- **CoreMotion `CMPedometer`** is the counter. The motion coprocessor counts steps all day even when Sole is closed, and keeps 7 days of history on device.
- **Live count**: `startUpdates(from: startOfDay)` while Sole is open, so the number ticks up as you walk.
- **Backfill**: on every launch/foreground, `queryPedometerData` hour by hour for any gap since the last save (up to 7 days). Nothing is lost if the app was not opened for days.
- **Extra metrics from the same sensor**: distance, floors climbed/descended, cadence and pace.
- **No double counting with Apple Watch**: steps are stored per hour per source. A day's total is the sum over hours of the *highest* source for that hour (phone vs. watch/other apps read from Health). Carrying a phone and wearing a watch counts once, not twice. This mirrors how Apple Health dedupes.

### iCloud storage
- **SwiftData with CloudKit** (private database, the user's own iCloud account). No server, no account sign-up.
- Model: `HourlySteps` (hour start, source, steps, distance, floors) and `DailySummary` (date, total, goal, goal met). Settings (goal, units) in `NSUbiquitousKeyValueStore`.
- CloudKit rules: all properties optional or defaulted, no unique constraints; dedupe in code by (hour, source).
- Reinstall or new iPhone: full history comes back from iCloud.

### Apple Health, both directions
- **Read**: `stepCount`, `distanceWalkingRunning`, `flightsClimbed` from all sources (Apple Watch, other apps) so Sole's history covers years, not just 7 days, and includes watch-only walks. `HKObserverQuery` + background delivery keeps it current.
- **Write**: Sole writes its hourly sensor counts to Health as Sole-sourced samples, plus any manual entries. Health's own source priority prevents these from inflating Health's total (iPhone already logs its steps to Health itself; Sole's samples sit alongside, deduped).
- Anchored queries (`HKAnchoredObjectQuery`) so each sync only moves what changed; deletions in Health are respected.
- Sync status visible in Settings: last synced time for Health and iCloud, with a "Sync now" button.

## v1 feature list
1. **Today**: live step count, progress arc toward the daily goal, distance, floors, active minutes, hourly bar chart.
2. **History**: week / month / year charts, daily average, best day, current goal streak. Tap a day for its hourly breakdown.
3. **Daily goal**: default 8,000, adjustable; streak counts consecutive goal days.
4. **Apple Health two-way sync** (above).
5. **iCloud storage and sync** (above).
6. **Onboarding**: three screens: what Sole does, Motion & Fitness permission, Health permission, then pick a goal. Works (sensor only) if Health is declined.
7. **Widgets**: Home Screen small and medium, Lock Screen circular and inline (WidgetKit extension, shared App Group store).
8. **Settings**: goal, units (km/mi), sync status, export CSV, permissions shortcuts.
9. **Accessibility**: Dynamic Type, VoiceOver labels on charts, light and dark mode.

## Later (v2+)
- Apple Watch app and complication.
- Goal reminder notification ("1,800 steps to go") in the evening.
- Achievements (first 10k day, 7-day streak, lifetime milestones).
- Live Activity for a tracked walk.
- Manual step entry/edit UI (data model supports it in v1).

## Out of scope
Accounts, social/leaderboards, ads, GPS route tracking.

## Design direction
- Three tabs: **Today**, **History**, **Settings**.
- Today leads with one large number (rounded, tabular figures) inside a 270° progress arc; stats row under it; hourly bars below.
- Palette: deep ink navy text, cool stone background, saffron accent for progress, green for goal met. Full dark mode.
- SF Pro Rounded for numbers, SF Pro for text. Standard iOS navigation and sheets, no custom chrome.

## Build order
1. Data model + SwiftData/CloudKit container + entitlements (iCloud, HealthKit, App Group).
2. Step engine: CMPedometer live + hourly backfill, writing `HourlySteps`.
3. Today screen.
4. HealthKit read/write sync with anchored queries + dedupe rule.
5. History screen.
6. Onboarding + Settings.
7. Widgets.

## Testing notes
- CMPedometer does not work in the Simulator; step counting needs a real iPhone. HealthKit and CloudKit need the paid developer account capabilities enabled on the bundle ID com.pandyabhavik.Sole.
