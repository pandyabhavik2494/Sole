# Sole v2: product, design and engineering spec

Status: proposal for Bhavik's review (2026-10-03). No app code written for v2 yet.
Mockups: docs/mockups-v2.html (open in a browser), also the "Sole Product Plan" artifact (https://claude.ai/artifact/7zMM1tyrMynSsWtHPb5x5x), version 2.
Builds on v1 (on main): CMPedometer steps, per-hour dedupe with Health, two-way step sync, Today/History/Settings, widgets, App Group `group.com.pandyabhavik.Sole`.

---

## 1. Product (principal PM)

### Problem
Apple Health stores everything but explains little. Numbers like "58 bpm" or "96%" mean nothing without knowing what is normal *for you* and whether things are moving in a good direction.

### Promise
**Sole tells you, in plain words, how your body is doing compared with your own normal.** Every number comes with three things: your usual range, the direction it is heading, and one sentence on what that means.

### Metrics in scope (Bhavik's list)
| Metric | HealthKit type | Usual source | How Sole explains it |
|---|---|---|---|
| Steps | `stepCount` (+ CMPedometer) | iPhone, Watch | Goal progress, pace vs. your usual day |
| Weight | `bodyMass` | Smart scale, manual | Smoothed trend weight, weekly rate of change |
| Blood oxygen | `oxygenSaturation` | Apple Watch | "Steady / within your range", lowest overnight reading |
| Active energy | `activeEnergyBurned` | Watch, iPhone | Calories from moving, vs. your usual |
| Resting energy | `basalEnergyBurned` | Watch | Calories from just being alive; with active = total burn |
| Heart rate | `heartRate` | Watch | Today's range (low to high) and when it peaked |
| Resting heart rate | `restingHeartRate` | Watch | Key recovery signal; trend vs. your 4-week normal |
| Walking heart rate avg | `walkingHeartRateAverage` | Watch | Fitness signal: lower over time = walks feel easier |
| Highlights | (computed by Sole) | n/a | Sole's own highlight cards, see below |

**Important:** Apple does not let other apps read the Health app's own Highlights or Trends. Sole computes its own highlights from the raw data, using the same idea (compare recent weeks to your longer history).

### Features

**F1. Daily Brief (top of Today).** Two or three plain sentences written from rules, e.g.
"You're on pace for a usual Friday. Resting heart rate is 56, a little below your normal, a good sign of recovery. Your weight trend is down 0.4 kg this week."
Rules pick the 2–3 most notable facts (biggest deviation from your normal first). No medical claims or diagnosis.

**F2. Vitals at a glance (Today).** One card per metric group: Heart, Energy, Body (weight), Oxygen. Each card shows the latest value, a **range bar** (your usual range as a band, today's value as a dot) and a one-word status: *Usual*, *Above usual*, *Below usual*, or *Learning* (fewer than 7 days of data).

**F3. Metric detail pages.** Tap any card: chart (Day/Week/Month/6 Months/Year) with your usual-range band drawn behind it, the trend sentence, a short "What this is" and "What moves it" explainer, and the data sources.

**F4. Trends tab.** One list of every metric with a sparkline and an arrow (up / down / steady) for the last 4 weeks vs. the 12 weeks before. Arrows are colored by meaning, not direction (resting heart rate going down is good, green).

**F5. Highlights tab.** A feed of cards, newest first, generated on device. Highlight types:
1. **Trend**: "Your resting heart rate has dropped 4 bpm over the past month."
2. **Off your usual**: "Resting heart rate is 9 bpm above your normal today." (neutral tone, mentions common causes: short sleep, illness, alcohol, hard training)
3. **Record**: "Most steps in a day since March: 18,204."
4. **Weekly recap** (Mondays): steps, active energy and resting HR vs. last week.
5. **Fitness signal**: "Walking is getting easier: walking heart rate down 5 bpm while your steps held steady."
6. **Pattern**: "Saturdays are your most active day."
7. **Streak**: goal streak milestones (carried from v1).

**F6. Energy made relatable.** Total burn = resting + active, shown as one stacked bar: "2,310 kcal today: 1,640 just keeping you going, 670 from moving."

**F7. Log weight.** Quick entry sheet from the Body card; Sole writes `bodyMass` to Health (two-way, like steps).

**F8. Steps (kept from v1).** Live CMPedometer count, goal ring, hourly bars, history, streak, dedupe with Watch. Moves into Today as the hero and into Trends/detail.

**F9. Widgets (updated).** Small: steps ring. Medium: steps + resting HR + active energy with status words. Lock Screen: steps circular, inline "7,842 steps · RHR 56".

**F10. Weekly summary notification (opt-in).** A local notification on Monday morning with the weekly recap highlight. Local only, no server.

### Out of scope for v2
Sleep, HRV, VO2 max, workouts (good candidates for v3; all readable with the same approach). Watch app. Medications, cycle, nutrition. Accounts, cloud, social, ads. Any diagnosis or medical advice.

### Edge cases the design must handle
- **No Apple Watch**: heart, oxygen and resting energy are usually empty. Cards show "Needs Apple Watch data" in a compact state, and the brief only talks about what exists. Steps, weight and (often) active energy still work.
- **Blood oxygen** is sparse (background readings a few times a day, more at night) and on some US Watches it is measured through the iPhone. Sole shows whatever Health has and never alarms on a single reading.
- **New user**: baselines need 7 days; until then status reads *Learning your normal* (Health history import usually fills this instantly).
- **Permissions**: users can deny any single type. HealthKit does not tell apps which read types were denied, so an empty metric is shown as "No data" with a link to Health settings, never as an error.

---

## 2. Design (principal UX, Apple Liquid Glass)

### Principles
1. **Content first, glass for controls.** Following Apple's Liquid Glass guidance, glass is used only on the navigation layer: the floating tab bar, toolbar buttons, the floating "Log" button and sheets. Content cards are solid, quiet surfaces so numbers stay legible.
2. **Words before numbers.** Every screen opens with a sentence, then the number, then the chart.
3. **Your normal is the reference.** The range band is the signature visual element, used on cards, detail charts and widgets.
4. **Color has meaning.** Each metric keeps Apple Health's category color so it feels familiar: steps/activity orange, energy red-orange, heart pink-red, oxygen cyan-blue, body purple. Status colors (good green, watch amber) are separate from metric colors. Never red for "bad" on health data; amber "worth a look" instead.

### Structure
- **Tabs (floating glass tab bar, minimizes on scroll):** Today · Trends · Highlights. Settings moves to a glass gear button in the Today toolbar.
- **Today:** large title + date, glass toolbar (gear, profile-free). Daily Brief card. Steps hero ring. Vitals grid (Heart, Energy, Body, Oxygen). Latest highlight preview.
- **Trends:** segmented range picker (glass), list of metrics with sparkline, arrow and change.
- **Highlights:** card feed, filter chips (All, Heart, Activity, Body).
- **Metric detail:** pushed screen. Chart with range band, scrubbing, trend sentence, explainer, sources.
- **Sheets (glass, medium detent):** Log weight, Edit goal.
- **Background:** a soft gradient tinted by today's step progress so the glass tab bar has something to refract; flat system background in Reduce Transparency mode.

### Type and layout
SF Pro Rounded for big numbers (tabular), SF Pro for text. Large titles. 16 pt margins, 12 pt card spacing, 22 pt card corner radius (concentric with the device). Dynamic Type to XXXL; cards reflow to one column.

### Accessibility
VoiceOver reads each card as one sentence ("Resting heart rate 56, below your usual range of 58 to 63"). Charts get audio graphs (Swift Charts accessibility). Reduce Transparency swaps glass for solid materials automatically; Reduce Motion disables ring and morph animations. Status never relies on color alone (word + arrow).

---

## 3. Engineering validation (principal engineer)

### Free personal team: what works
| Need | Framework | Free account? | Notes |
|---|---|---|---|
| Read all 8 metric types | HealthKit | Yes | Already using HealthKit in v1 |
| Write weight and steps | HealthKit | Yes | Share permission for `bodyMass`, `stepCount` |
| Background updates | HealthKit background delivery | Yes | Entitlement already in v1; heart rate types deliver at most hourly |
| Charts with bands | Swift Charts (`AreaMark` + `LineMark` + `RuleMark`) | Yes | |
| Liquid Glass | SwiftUI on iOS 26 SDK (`glassEffect`, `GlassEffectContainer`, tab bar minimize) | Yes | No entitlement needed |
| Widgets | WidgetKit + App Group | Yes | Already in v1 |
| Weekly notification | UserNotifications, local only | Yes | Remote push is not available on free accounts, and not needed |
| On-device storage | SwiftData | Yes | |

### What a free account rules out (not in this plan)
- iCloud / CloudKit sync (already dropped; Health is the backup).
- Remote push notifications, App Store / TestFlight distribution.
- Reading Apple's own Health Highlights and Trends (no public API, for any account).

### Living with a free account
- The app must be re-installed from Xcode every **7 days** (provisioning expires). Data stays on the phone between installs.
- Free teams can have at most 3 sideloaded apps on a device and 10 new App IDs per week.

### Minimum iOS
**Raise the minimum from iOS 17 to iOS 26.** The current build already gets the glass tab bar automatically from the iOS 26 SDK, but custom glass (`.glassEffect`, morphing toolbar buttons, `tabBarMinimizeBehavior`) needs iOS 26 APIs. It is a personal app on Bhavik's own iPhone, so there is no reason to keep `#available` branches.

### Data architecture
- **HealthMetricsService**: one `HKStatisticsCollectionQuery` per metric (daily buckets; hourly for today's heart rate). Options: `cumulativeSum` for energy and steps; `discreteAverage/Min/Max` for heart, oxygen; `mostRecent` for weight. Never load raw heart-rate samples.
- **Daily cache (SwiftData `DailyMetric`)**: date, metric, value, min, max, sample count, source summary. Rebuildable from Health at any time; makes charts, baselines and widgets fast. Widgets read a small JSON snapshot in the App Group (Health data cannot be read while the phone is locked).
- **Sync**: `HKObserverQuery` + background delivery per type → refresh affected days → recompute baselines and highlights → reload widget timelines.
- **First run**: import full history (as v1 does for steps), newest first, so Today fills in seconds and long trends fill in the background.

### The "understanding" math (deterministic, unit-tested)
- **Usual range (baseline)**: for each metric, the 25th–75th percentile of daily values over the previous 28 days (excluding today), median as the center. Needs ≥ 7 days with data; otherwise *Learning*.
- **Status**: *Above* / *Below usual* when today's value is outside the band by more than a per-metric minimum (RHR 3 bpm, walking HR 4 bpm, SpO2 2 points, energy 10%, steps 15%, weight n/a).
- **Trend**: mean of the last 28 days vs. the 84 days before. Reported only when the change beats a minimum (RHR 2 bpm, walking HR 3 bpm, weight 0.5 kg, steps 10%, active energy 10%, SpO2 1 point) and both windows have ≥ 14 days of data.
- **Trend weight**: exponential moving average (α = 0.1) over daily weights, so one salty dinner doesn't look like gaining a kilo.
- **Good/bad direction** per metric (for arrow color): RHR and walking HR down = good; steps and active energy up = good; SpO2 steady = good; weight is neutral unless the user sets a weight goal (later).
- **Brief and highlight text** come from templates filled by these numbers. Same input, same sentence, which keeps health wording safe and testable.

### Risks
- Sparse data (no Watch, few SpO2 readings) → designed empty states, minimum-sample rules.
- Background delivery is best effort; Sole also refreshes on every foreground.
- Copy must avoid medical claims; every detail page links to "Not medical advice. Talk to a doctor about readings that worry you."

---

## 4. Build order (each step runs on the iPhone before the next)
1. **iOS 26 + Liquid Glass shell**: raise deployment target, new tab structure (Today, Trends, Highlights), gear → Settings, glass toolbar and tab bar minimize. Existing steps screens keep working.
2. **HealthKit read for the 7 new types** + `HealthMetricsService` + `DailyMetric` cache + history import. Settings shows per-metric status.
3. **Baselines and statuses** (pure Swift, unit tests).
4. **Today redesign**: Daily Brief, steps hero, vitals grid with range bars.
5. **Metric detail pages** with banded charts and explainers.
6. **Trends tab**.
7. **Highlights engine + tab** (unit-tested rules).
8. **Log weight** (write `bodyMass`).
9. **Widgets update + weekly local notification**.

## 5. Open choices (defaults picked)
- Minimum iOS 26: **yes** (default).
- Brief written by rules rather than Apple's on-device AI model: **rules** (default; works on every iPhone, wording is predictable). Apple's Foundation Models framework also works on a free account and could rephrase the brief more naturally on Apple Intelligence iPhones; it can be added later as an option.
