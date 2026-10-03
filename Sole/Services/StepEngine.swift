import CoreMotion
import Foundation
import Observation

/// Keeps Sole's store in step with the iPhone's motion sensor and publishes today's numbers.
///
/// - On launch and each return to the foreground it backfills every hour since the last run
///   (up to the sensor's 7 days), so days the app wasn't opened are filled in.
/// - While Sole is open it follows the live count and writes the current hour.
/// - When Apple Health is connected it reads every other source (Apple Watch, other apps, older
///   history) and writes Sole's sensor counts back.
@MainActor
@Observable
final class StepEngine {
    private(set) var today: DayDetail
    private(set) var streak = 0
    private(set) var isSyncing = false
    private(set) var motionStatus: CMAuthorizationStatus = PedometerService.authorizationStatus
    private(set) var isHealthConnected = false
    private(set) var lastHealthSync: Date? = UserDefaults.standard.object(forKey: StepEngine.lastHealthSyncKey) as? Date
    private(set) var lastSyncError: String?

    @ObservationIgnored let store: StepStore
    @ObservationIgnored let preferences: Preferences
    @ObservationIgnored private let pedometer = PedometerService()
    @ObservationIgnored private let health = HealthService()
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private var liveDay: Date?
    @ObservationIgnored private var liveHour: Date?
    @ObservationIgnored private var isCatchingUp = false
    @ObservationIgnored private var pendingSave: Task<Void, Never>?

    private static let lastBackfillKey = "lastPedometerBackfill"
    private static let lastHealthSyncKey = "lastHealthSync"
    /// How far back the first Health import reaches.
    private static let healthImportDays = 365

    init(store: StepStore, preferences: Preferences, calendar: Calendar = .current) {
        self.store = store
        self.preferences = preferences
        self.calendar = calendar
        self.today = .empty(for: .now, calendar: calendar)
        refreshToday()
    }

    /// Call once at launch. Health wakes Sole in the background when new steps arrive.
    func startObservingHealth() {
        guard HealthService.isAvailable else { return }
        health.observeStepChanges { [weak self] in
            await self?.sync()
        }
        Task { isHealthConnected = await health.hasRequestedAuthorization() }
    }

    // MARK: Lifecycle

    func becameActive() async {
        await sync()
        startLive()
    }

    func enteredBackground() {
        stopLive()
        store.save()
    }

    /// Fills any missed hours from the sensor, syncs with Health, and saves.
    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        await backfillFromSensor()
        await syncHealth()
        refreshToday()
        store.save()
    }

    /// Changes from another device arrived through iCloud: rebuild the recent days that could include them.
    func cloudDataDidImport() {
        let today = calendar.startOfDay(for: .now)
        let days = (0..<8).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        store.recomputeDays(Set(days), goal: preferences.dailyGoal)
        refreshToday()
        scheduleSave()
    }

    /// Call after the goal changes so today's summary and the streak use the new goal.
    func goalDidChange() {
        store.recomputeDays([calendar.startOfDay(for: .now)], goal: preferences.dailyGoal)
        refreshToday()
        scheduleSave()
    }

    /// Asks the sensor for the last hour, which shows the Motion & Fitness prompt the first time.
    func requestMotionAccess() async {
        let now = Date()
        _ = try? await pedometer.reading(from: now.addingTimeInterval(-3600), to: now)
        motionStatus = PedometerService.authorizationStatus
    }

    // MARK: Sensor backfill

    func backfillFromSensor(now: Date = .now) async {
        motionStatus = PedometerService.authorizationStatus
        guard PedometerService.isAvailable, motionStatus != .denied, motionStatus != .restricted else { return }

        let currentHour = calendar.startOfHour(for: now)
        // The sensor's oldest hour is partly outside its 7 days, so start at the next full hour.
        let oldest = calendar.date(byAdding: .hour, value: 1, to: calendar.startOfHour(for: now.addingTimeInterval(-PedometerService.historyLimit))) ?? currentHour
        var hour = oldest
        if let last = UserDefaults.standard.object(forKey: Self.lastBackfillKey) as? Date,
           let rewound = calendar.date(byAdding: .hour, value: -2, to: calendar.startOfHour(for: last)) {
            hour = max(oldest, rewound)
        }

        var samples: [HourSample] = []
        while hour <= currentHour {
            guard let next = calendar.date(byAdding: .hour, value: 1, to: hour) else { break }
            do {
                let reading = try await pedometer.reading(from: hour, to: min(next, now))
                samples.append(HourSample(hour: hour, steps: reading.steps, distanceMeters: reading.distanceMeters, floors: reading.floorsAscended))
            } catch {
                if PedometerService.authorizationStatus == .denied { break }
            }
            hour = next
        }
        motionStatus = PedometerService.authorizationStatus
        guard !samples.isEmpty else { return }

        // The sensor is the truth for recent hours on this iPhone. For older hours keep the higher
        // value, so history restored from iCloud (counted by a previous iPhone) is never lowered.
        let recent = calendar.date(byAdding: .hour, value: -3, to: currentHour) ?? currentHour
        let changed = store.upsert(samples, source: .phone) { $0 >= recent ? .replace : .keepHigher }
        store.recomputeDays(changed.union([calendar.startOfDay(for: now)]), goal: preferences.dailyGoal, now: now)
        UserDefaults.standard.set(now, forKey: Self.lastBackfillKey)
    }

    // MARK: Apple Health

    /// Shows the Health permission sheet, then imports history.
    func connectHealth() async {
        guard HealthService.isAvailable else { return }
        do {
            try await health.requestAuthorization()
        } catch {
            lastSyncError = error.localizedDescription
        }
        isHealthConnected = await health.hasRequestedAuthorization()
        if isHealthConnected {
            await sync()
        }
    }

    func syncHealth(now: Date = .now) async {
        guard HealthService.isAvailable else { return }
        isHealthConnected = await health.hasRequestedAuthorization()
        guard isHealthConnected else { return }

        let today = calendar.startOfDay(for: now)
        let start: Date
        if let lastHealthSync {
            // Re-read the day before the last sync too: Watch data can arrive late.
            start = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: lastHealthSync)) ?? today
        } else {
            start = calendar.date(byAdding: .day, value: -Self.healthImportDays, to: today) ?? today
        }
        let end = calendar.date(byAdding: .hour, value: 1, to: calendar.startOfHour(for: now)) ?? now

        do {
            let hours = try await health.hourlyTotals(from: start, to: end)
            // An empty answer for the whole window usually means read access is off, not that every
            // walk was deleted, so only clear hours missing from Health when it returned something.
            let changed = store.upsert(hours, source: .health, clearing: hours.isEmpty ? nil : start..<end) { _ in .replace }
            store.recomputeDays(changed, goal: preferences.dailyGoal, now: now)

            try await writeSensorHoursToHealth(now: now)

            lastHealthSync = now
            lastSyncError = nil
            UserDefaults.standard.set(now, forKey: Self.lastHealthSyncKey)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    /// Writes this iPhone's completed hours from the last 8 days whose count changed since they were last written.
    private func writeSensorHoursToHealth(now: Date) async throws {
        guard health.canWriteSteps else { return }
        let currentHour = calendar.startOfHour(for: now)
        let start = calendar.date(byAdding: .day, value: -8, to: currentHour) ?? currentHour
        let pending = store.rows(from: start, to: currentHour, source: .phone)
            .filter { $0.steps > 0 && $0.steps != $0.healthWrittenSteps }
        guard !pending.isEmpty else { return }

        try await health.save(pending.map(\.sample), calendar: calendar)
        for row in pending {
            row.healthWrittenSteps = row.steps
        }
    }

    // MARK: Live count

    private func startLive() {
        guard PedometerService.isAvailable else { return }
        let now = Date()
        liveDay = calendar.startOfDay(for: now)
        liveHour = calendar.startOfHour(for: now)
        pedometer.startLiveUpdates(from: calendar.startOfDay(for: now)) { [weak self] reading in
            self?.handleLive(reading)
        }
    }

    private func stopLive() {
        pedometer.stopLiveUpdates()
        liveDay = nil
        liveHour = nil
    }

    private func handleLive(_ reading: PedometerReading) {
        guard !isCatchingUp, let liveDay else { return }
        let hour = calendar.startOfHour(for: reading.end)

        // At midnight or the top of the hour, settle the hour that just ended from the sensor
        // before attributing new steps, so they land in the right hour.
        if calendar.startOfDay(for: reading.end) != liveDay || hour != liveHour {
            isCatchingUp = true
            Task {
                stopLive()
                await sync()
                isCatchingUp = false
                startLive()
            }
            return
        }

        // The live reading is today's running total. This hour's share is that total minus the
        // stored phone steps for today's earlier hours.
        let earlier = store.rows(from: liveDay, to: hour, source: .phone)
        let sample = HourSample(
            hour: hour,
            steps: max(0, reading.steps - earlier.reduce(0) { $0 + $1.steps }),
            distanceMeters: max(0, reading.distanceMeters - earlier.reduce(0) { $0 + $1.distanceMeters }),
            floors: max(0, reading.floorsAscended - earlier.reduce(0) { $0 + $1.floorsAscended })
        )
        let changed = store.upsert([sample], source: .phone) { _ in .replace }
        guard !changed.isEmpty else { return }
        store.recomputeDays(changed, goal: preferences.dailyGoal)
        refreshToday()
        scheduleSave()
    }

    // MARK: Publishing

    func refreshToday() {
        today = store.dayDetail(for: .now)
        streak = store.currentStreak()
    }

    /// Saves at most every 30 seconds while walking, so iCloud isn't sent a change per step.
    private func scheduleSave() {
        guard pendingSave == nil else { return }
        pendingSave = Task {
            try? await Task.sleep(for: .seconds(30))
            store.save()
            pendingSave = nil
        }
    }
}
