# Sole architecture

How the v2 app is put together. The product spec is [sole-v2-spec.md](sole-v2-spec.md); this note
covers module boundaries, data flow, concurrency, and how errors and empty data are handled. Keep it
current when any of those change.

## Data flow

```
Apple Health ──statistics queries──▶ HealthMetricsService ──[DailyValue]──▶ MetricsEngine
  (8 types + sleep)                   (nonisolated, @concurrent)              (@MainActor)
                                                                                │
CMPedometer ──▶ StepEngine ──DailySummary (v1 merge, dedupe)───────────────────▶│
                                                                                ▼
Day tags (SwiftData DayTag) ─────────────────────────────────────────▶ DailyMetric cache (SwiftData)
                                                                                │
                                                                                ▼
                                                         Normal (pure): usual range, pace, status,
                                                         trend, headline, highlights, recap
                                                                                │
                                                     ┌──────────────┬───────────┴────────┬──────────┐
                                                     ▼              ▼                    ▼          ▼
                                                  Today/Trends   Widgets (App Group   App Intents  Weekly
                                                  Recap/Detail   JSON snapshot)       (Siri)       notification
```

1. **Health → daily statistics.** `HealthMetricsService` runs one `HKStatisticsCollectionQuery`
   per metric with daily buckets anchored at local midnight (`cumulativeSum` for energy;
   `discreteAverage/Min/Max` for heart rate and blood oxygen; `mostRecent` for weight). Raw
   heart-rate samples are never loaded. Today's heart rate also gets hourly buckets for "when it
   peaked". Sleep is the one category type: asleep intervals for last night are read and merged
   (overlapping Watch and iPhone intervals are unioned, never added).
2. **Steps** keep the v1 path untouched: CMPedometer + Health hourly rows, per-hour dedupe, two-way
   sync, `DailySummary`. `MetricsEngine` reads daily step totals from `DailySummary`, so steps in
   "your normal" are the same deduped numbers the user already sees.
3. **Cache.** `DailyMetric` rows (day key, metric, value, min, max) in SwiftData. The cache is
   rebuildable from Health at any time; it exists so charts, baselines and widgets don't wait on
   Health, and so Today renders instantly at launch.
4. **Baselines.** `Normal` is pure Swift over value types (`[DayKey: Double]`, tags, `Date`,
   `Calendar`). No HealthKit, SwiftData or SwiftUI imports, so every rule is unit tested.
5. **Outputs.** Views read `MetricsEngine.insights` (an immutable `Insights` value). Widgets and
   App Intents read a small JSON snapshot in the App Group because Health data can't be read while
   the phone is locked.

## Module boundaries

| Module | Owns | Must not |
| --- | --- | --- |
| `Sole/Model/Normal` | Pure rules: `DayKey`, `Metric`, `UsualRange`, `UsualPace`, `Status`, `Trend`, `Headline`, `Highlights`, `Recap`, `SleepMath`, units | Import HealthKit, SwiftData or SwiftUI |
| `Sole/Model` | SwiftData models (`HourlySteps`, `DailySummary`, `DailyMetric`, `DayTag`), v1 `StepMath` | Talk to Health |
| `Sole/Services` | Health, CoreMotion, persistence, engines, notifications, privacy lock | Format text for the UI |
| `Sole/Views` | SwiftUI screens | Query Health or SwiftData directly (except `@Query` for lists) |
| `Shared` | Code compiled into the app and the widget: palette, formatting, App Group snapshot, intents | Depend on app-only types |

## Day keys, time zones and DST

Daily values are keyed by `DayKey` (year, month, day in the user's calendar), not by `Date`. A
day stays the same day after travelling across time zones, and a 23- or 25-hour DST day is still
one bucket. Health buckets are anchored with calendar components (`DateComponents(day: 1)`), which
HealthKit applies DST-correctly. "Same time on the same weekday" for usual pace is computed with
calendar hour/minute components, not by adding seconds.

## Concurrency

Swift 6 language mode (complete strict concurrency) in every target.

- **Main actor:** SwiftUI, `StepEngine`, `MetricsEngine`, `Preferences`, all SwiftData access
  (one `mainContext`; `ModelContext` is not Sendable, so it never leaves the main actor).
  `PedometerService` is main-actor isolated; CoreMotion callbacks are `@Sendable` and hop back.
- **Off the main actor:** `HealthMetricsService` is a `Sendable` final class holding only `let`
  properties (`HKHealthStore` is thread-safe). Its query methods are `@concurrent`, so they run on
  the global executor whatever actor calls them, and they return `Sendable` value types.
- **Pure math** runs wherever it's called; it's microseconds for ~400 days × 8 metrics, so the
  engine runs it on the main actor after the awaits complete rather than adding a hop.
- **Observer queries** call back on a HealthKit queue; the handler hops to the main actor, refreshes,
  then calls HealthKit's completion handler (documented as callable from any thread).
- Refreshes are coalesced: a refresh requested while one runs sets a flag and runs once more after.

## Errors and empty states

HealthKit never tells an app whether *read* access was denied; a denied type looks exactly like a
type with no data. So Sole never shows "permission denied" errors for reads:

| Situation | What the user sees |
| --- | --- |
| Health unavailable (iPad without Health) | Steps-only app, vitals section hidden |
| v2 types never requested (upgrade from v1) | "Connect more Health data" card on Today |
| A type returns nothing (denied, or no device records it) | Row says "No data" with "Needs Apple Watch" for Watch-only types, links to Health settings; excluded from the tally and headline |
| Fewer than 7 days with data | Status *Learning*, range shown as "learning your normal" |
| Fewer than 14 days in either trend window | No trend arrow (Steady is never claimed without data) |
| One blood-oxygen reading | Shown, never alarmed on (status needs a range from ≥ 7 days) |
| Health query throws | Last cached values stay on screen; Settings shows the error and a Sync now button |
| Sleep missing | Sleep chip is hidden |

Health writes (weight) surface errors in the Add sheet and never write to the cache unless Health
accepted the sample.

## Status rules (summary)

Defined in `Metric` and `Normal`; the spec has the reasoning.

- **Usual range:** 25th–75th percentile (linear interpolation) of daily values over the 28 days
  before today, leaving out days tagged sick or travel; median as the centre; needs ≥ 7 days.
- **Status:** outside the band by more than the metric's minimum → *Better* or *Worth a look*
  depending on the metric's polarity. Blood oxygen only flags low values. Weight has no
  Better/Worth a look (no goal yet) and is not in the tally.
- **Cumulative metrics today** (steps, burned energy) are partial until midnight, so today is
  compared with the **usual pace**: the median of the same weekday's cumulative total up to the
  same clock time over the last 8 weeks. Steps use their hourly rows; burned energy uses hourly
  Health statistics for the last 8 weeks.
- **Trend:** mean of the last 28 days vs. the 84 before, each needing ≥ 14 days; tagged sick and
  travel days are left out of both windows.
- **Headline:** largest *Worth a look* deviation, else largest *Better*, else "Everything is in
  your usual range"; the second line adds steps pace. Deviation is measured in multiples of the
  metric's minimum so bpm and kcal compare fairly.

## Privacy

All data stays on device. Lock Screen widgets show steps only unless the user opts in; weight can
be hidden everywhere (it is then also left out of widgets, Siri, the recap and the PDF); optional
Face ID lock covers the app when it returns from the background. At most one local notification a
day (the Monday recap).

## Free personal team

No iCloud, no push, no paid capabilities. App Intents (Siri / Shortcuts) and the Control Center
control are WidgetKit/App Intents features that don't need extra entitlements; they need a check
on device because Siri phrase registration can behave differently on development builds.
