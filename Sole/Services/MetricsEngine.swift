import Foundation
import Observation

/// Keeps the `DailyMetric` cache in step with Apple Health and publishes what the screens show.
///
/// Health queries run off the main actor in `HealthMetricsService`; this class awaits them, then
/// writes the cache and updates its state on the main actor. Refreshes are coalesced: a refresh
/// asked for while one is running runs once more when it finishes.
@MainActor
@Observable
final class MetricsEngine {
    enum Access: Equatable {
        /// No Health on this device (some iPads).
        case unavailable
        /// The v2 permission sheet hasn't been shown yet (new install, or upgraded from v1).
        case notRequested
        /// The sheet was shown. Health doesn't say what was allowed; empty metrics show "No data".
        case requested
    }

    private(set) var access: Access = HealthMetricsService.isAvailable ? .notRequested : .unavailable
    /// Daily values for roughly the last 13 months, including steps from `StepEngine`.
    private(set) var series: [Metric: [DayKey: DailyValue]] = [:]
    private(set) var tags: [DayKey: Set<DayTagKind>] = [:]
    private(set) var units: UnitPreferences
    /// Seconds asleep last night, or nil when Health has no sleep for it.
    private(set) var lastNightSleep: TimeInterval?
    /// Today's heart rate low and high by hour.
    private(set) var todayHeartRate: [HourRange] = []
    private(set) var isRefreshing = false
    private(set) var isImportingHistory = false
    private(set) var lastRefresh: Date?
    private(set) var lastError: String?
    /// The oldest day with any cached Health data, for "learned from 2 years of data".
    private(set) var historyStart: DayKey?
    /// Usual ranges, statuses, trends and the headline for today.
    private(set) var insights: Insights

    @ObservationIgnored let store: MetricsStore
    @ObservationIgnored let service: HealthMetricsService
    @ObservationIgnored private let stepStore: StepStore
    @ObservationIgnored let calendar: Calendar
    @ObservationIgnored private var refreshAgain = false
    /// Active energy by hour for the last 8 weeks, for the energy "usual pace".
    @ObservationIgnored private(set) var hourlyActiveEnergy: [Date: Double] = [:]
    /// Merged steps by hour for the 8 weeks before today, for the steps "usual pace".
    @ObservationIgnored private var hourlySteps: [Date: Double] = [:]

    /// Days kept in memory for screens. Trends need 28 + 84 days; the Year chart needs 365.
    static let memoryDays = 400
    /// Days re-read from Health on every refresh: enough for every baseline and trend, and it
    /// picks up late Watch data and deletions without anchored queries per type.
    static let refreshDays = 130

    private static let historyImportedKey = "metricsHistoryImported"
    private static let unitsKey = "unitPreferences"

    init(store: MetricsStore, stepStore: StepStore, service: HealthMetricsService = HealthMetricsService(), calendar: Calendar = .current) {
        self.store = store
        self.stepStore = stepStore
        self.service = service
        self.calendar = calendar
        self.units = UserDefaults.standard.data(forKey: Self.unitsKey).flatMap { try? JSONDecoder().decode(UnitPreferences.self, from: $0) } ?? .metric
        self.insights = .empty(day: DayKey(.now, calendar: calendar))
        reloadFromCache()
    }

    /// Call once at launch: Health wakes Sole in the background when any metric changes.
    func start() {
        guard HealthMetricsService.isAvailable else { return }
        service.observeChanges { [weak self] in
            await self?.refresh()
        }
        Task { await updateAccess() }
    }

    // MARK: Permission

    /// Shows the Health sheet for every v2 type, then reads history.
    func connect() async {
        guard HealthMetricsService.isAvailable else { return }
        do {
            try await service.requestAuthorization()
        } catch {
            lastError = error.localizedDescription
        }
        await updateAccess()
        await refresh()
    }

    private func updateAccess() async {
        guard HealthMetricsService.isAvailable else {
            access = .unavailable
            return
        }
        access = await service.hasRequestedAuthorization() ? .requested : .notRequested
    }

    // MARK: Refresh

    /// Re-reads recent days from Health, then (the first time) all older history.
    func refresh(now: Date = .now) async {
        if isRefreshing {
            refreshAgain = true
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        repeat {
            refreshAgain = false
            await refreshOnce(now: now)
        } while refreshAgain

        if !UserDefaults.standard.bool(forKey: Self.historyImportedKey), access == .requested {
            await importHistory(now: now)
        }
    }

    private func refreshOnce(now: Date) async {
        await updateAccess()
        guard access == .requested else {
            reloadFromCache()
            return
        }

        let newUnits = await service.preferredUnits()
        if newUnits != units {
            units = newUnits
            UserDefaults.standard.set(try? JSONEncoder().encode(newUnits), forKey: Self.unitsKey)
        }

        let today = DayKey(now, calendar: calendar)
        let first = today.adding(days: -Self.refreshDays)
        await read(Metric.fromHealth, from: first, through: today, now: now)
        await readContext(now: now)

        lastRefresh = now
        reloadFromCache()
    }

    /// Reads daily values for each metric in parallel and writes them to the cache. One metric
    /// failing doesn't stop the others; the last error is kept for Settings.
    private func read(_ metrics: [Metric], from first: DayKey, through last: DayKey, now: Date) async {
        let start = first.start(in: calendar)
        let end = min(now, last.adding(days: 1).start(in: calendar))
        let service = service
        let calendar = calendar

        let results = await withTaskGroup(of: (Metric, Result<[DailyValue], Error>).self) { group in
            for metric in metrics {
                group.addTask {
                    do {
                        return (metric, .success(try await service.dailyValues(for: metric, from: start, to: end, calendar: calendar)))
                    } catch {
                        return (metric, .failure(error))
                    }
                }
            }
            var collected: [(Metric, Result<[DailyValue], Error>)] = []
            for await result in group { collected.append(result) }
            return collected
        }

        var failure: Error?
        for (metric, result) in results {
            switch result {
            case .success(let values):
                store.replace(metric, with: values, from: first, through: last)
            case .failure(let error):
                failure = error
            }
        }
        store.save()
        lastError = failure?.localizedDescription
    }

    /// Sleep, today's hourly heart rate and recent hourly active energy.
    private func readContext(now: Date) async {
        let today = DayKey(now, calendar: calendar)
        let window = SleepMath.lastNightWindow(for: today, calendar: calendar)
        let startOfToday = today.start(in: calendar)
        let paceStart = today.adding(days: -UsualPace.weeks * 7 - 1).start(in: calendar)

        async let sleep = try? service.asleepIntervals(from: window.start, to: window.end)
        async let heart = try? service.hourlyHeartRate(from: startOfToday, to: now)
        async let energy = try? service.hourlySums(for: .activeEnergy, from: paceStart, to: now, calendar: calendar)

        let intervals = await sleep ?? []
        let duration = SleepMath.asleepDuration(intervals, within: window)
        lastNightSleep = duration > 0 ? duration : nil
        todayHeartRate = await heart ?? []
        hourlyActiveEnergy = await energy ?? [:]
    }

    /// Reads everything older than the refresh window, newest year first, so long charts fill in
    /// while Today is already usable.
    private func importHistory(now: Date) async {
        isImportingHistory = true
        defer { isImportingHistory = false }

        let today = DayKey(now, calendar: calendar)
        let earliest = DayKey(max(service.earliestPermittedDate, calendar.date(byAdding: .year, value: -10, to: now) ?? now), calendar: calendar)
        var last = today.adding(days: -Self.refreshDays - 1)
        while last >= earliest {
            let first = max(earliest, last.adding(days: -364))
            await read(Metric.fromHealth, from: first, through: last, now: now)
            reloadFromCache()
            last = first.adding(days: -1)
        }
        UserDefaults.standard.set(true, forKey: Self.historyImportedKey)
    }

    // MARK: Cache

    /// Reloads screens' data from the cache and the step store.
    func reloadFromCache(now: Date = .now) {
        let today = DayKey(now, calendar: calendar)
        let first = today.adding(days: -Self.memoryDays)
        var loaded: [Metric: [DayKey: DailyValue]] = [:]
        for metric in Metric.fromHealth {
            loaded[metric] = store.values(for: metric, from: first, through: today)
        }
        loaded[.steps] = stepValues(from: first)
        series = loaded
        tags = store.tags(from: first, through: today)
        historyStart = store.oldestDay()
        let startOfToday = today.start(in: calendar)
        hourlySteps = stepStore.hourlySteps(from: today.adding(days: -UsualPace.weeks * 7 - 1).start(in: calendar), to: startOfToday)
        rebuildInsights(now: now)
    }

    /// Recomputes statuses and the headline from what's in memory. Pure and fast (milliseconds).
    func rebuildInsights(now: Date = .now) {
        insights = InsightBuilder.build(InsightBuilder.Input(
            series: series,
            tags: tags,
            hourlySteps: hourlySteps,
            hourlyActiveEnergy: hourlyActiveEnergy,
            now: now,
            calendar: calendar
        ))
    }

    /// Daily steps from v1's merged summaries, so steps here match the step screens exactly.
    private func stepValues(from first: DayKey) -> [DayKey: DailyValue] {
        var result: [DayKey: DailyValue] = [:]
        for summary in stepStore.summaries(from: first.start(in: calendar), to: .distantFuture) where summary.steps > 0 {
            let day = DayKey(summary.day, calendar: calendar)
            let value = Double(summary.steps)
            if let existing = result[day], existing.value >= value { continue }
            result[day] = DailyValue(day: day, metric: .steps, value: value, min: nil, max: nil)
        }
        return result
    }

    /// Call after a sync so step baselines use the new daily totals.
    func stepsDidChange(now: Date = .now) {
        let today = DayKey(now, calendar: calendar)
        series[.steps] = stepValues(from: today.adding(days: -Self.memoryDays))
        hourlySteps = stepStore.hourlySteps(from: today.adding(days: -UsualPace.weeks * 7 - 1).start(in: calendar), to: today.start(in: calendar))
        rebuildInsights(now: now)
    }

    /// Call as the live count moves: only today's total changes, so this skips the store.
    func todayStepsDidChange(_ steps: Int, now: Date = .now) {
        let today = DayKey(now, calendar: calendar)
        guard series[.steps]?[today]?.value != Double(steps) else { return }
        series[.steps, default: [:]][today] = DailyValue(day: today, metric: .steps, value: Double(steps), min: nil, max: nil)
        rebuildInsights(now: now)
    }

    // MARK: Logging

    enum LogError: LocalizedError {
        case healthUnavailable
        case notAllowed

        var errorDescription: String? {
            switch self {
            case .healthUnavailable: "Apple Health isn't available on this device."
            case .notAllowed: "Sole isn't allowed to save weight. Turn it on in the Health app: Profile › Apps › Sole."
            }
        }
    }

    /// Saves a weight (in kilograms) to Apple Health, then reads it back into the cache. Nothing
    /// is cached unless Health accepted the sample.
    func logWeight(kilograms: Double, at date: Date = .now) async throws {
        guard HealthMetricsService.isAvailable else { throw LogError.healthUnavailable }
        if access == .notRequested {
            try await service.requestAuthorization()
            await updateAccess()
        }
        guard service.canWriteWeight else { throw LogError.notAllowed }
        try await service.saveWeight(kilograms: kilograms, at: date)
        await refresh()
    }

    /// The most recent weight in kilograms, for the Add sheet's starting value.
    var latestWeight: Double? {
        series[.weight]?.max { $0.key < $1.key }?.value.value
    }

    // MARK: Tags

    func setTags(_ kinds: Set<DayTagKind>, on day: DayKey) {
        store.setTags(kinds, on: day)
        store.save()
        tags[day] = kinds.isEmpty ? nil : kinds
        rebuildInsights()
    }
}
