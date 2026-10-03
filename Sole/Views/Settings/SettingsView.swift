import CoreMotion
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(StepEngine.self) private var engine
    @Environment(Preferences.self) private var preferences
    @Environment(\.openURL) private var openURL
    @Query(sort: \DailySummary.day) private var summaries: [DailySummary]

    var body: some View {
        @Bindable var preferences = preferences
        Group {
            Form {
                Section {
                    healthRow
                    statusRow(
                        icon: "internaldrive.fill", tint: Color(rgb: 0x7D8799), title: "History",
                        detail: storageDetail, state: "On", isOn: true
                    )
                    statusRow(
                        icon: "figure.walk.motion", tint: Color(rgb: 0xFF9F0A), title: "Motion sensor",
                        detail: motionDetail, state: motionIsOn ? "On" : "Off", isOn: motionIsOn
                    )
                    Button {
                        Task { await engine.sync() }
                    } label: {
                        HStack {
                            Text(engine.isSyncing ? "Syncing…" : "Sync now")
                            Spacer()
                            if engine.isSyncing { ProgressView() }
                        }
                    }
                    .disabled(engine.isSyncing)
                } header: {
                    Text("Sync")
                } footer: {
                    if let error = engine.lastSyncError {
                        Text(error)
                    }
                }

                Section("Goal & units") {
                    Picker("Daily goal", selection: $preferences.dailyGoal) {
                        ForEach(goalOptions, id: \.self) { Text(Format.steps($0)).tag($0) }
                    }
                    Picker("Distance", selection: $preferences.distanceUnit) {
                        ForEach(DistanceUnit.allCases) { Text($0.title).tag($0) }
                    }
                }

                Section {
                    ShareLink(item: export, preview: SharePreview(export.fileName, image: Image(systemName: "tablecells"))) {
                        Label("Export as CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(summaries.isEmpty)
                } header: {
                    Text("Data")
                } footer: {
                    Text("One row per day: steps, distance, floors and whether the goal was met. Opens in Numbers, Excel or Google Sheets.")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                } footer: {
                    Text("Your steps stay on your iPhone and in Apple Health. Sole has no account and no server.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Settings")
        }
    }

    // MARK: Rows

    @ViewBuilder
    private var healthRow: some View {
        if !HealthService.isAvailable {
            statusRow(icon: "heart.fill", tint: Color(rgb: 0xFF3B5C), title: "Apple Health", detail: "Not available on this device", state: "Off", isOn: false)
        } else if engine.isHealthConnected {
            Button {
                if let url = URL(string: "x-apple-health://") { openURL(url) }
            } label: {
                statusRow(icon: "heart.fill", tint: Color(rgb: 0xFF3B5C), title: "Apple Health", detail: healthDetail, state: "On", isOn: true)
            }
            .accessibilityHint("Opens the Health app, where you can change what Sole reads and writes")
        } else {
            Button {
                Task { await engine.connectHealth() }
            } label: {
                statusRow(icon: "heart.fill", tint: Color(rgb: 0xFF3B5C), title: "Apple Health", detail: "Read Watch steps and save Sole's counts", state: "Connect", isOn: false)
            }
        }
    }

    private func statusRow(icon: String, tint: Color, title: String, detail: String, state: String, isOn: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
            }
            Spacer()
            Text(state)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isOn ? Palette.good : Palette.accent)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Text

    private var healthDetail: String {
        guard let last = engine.lastHealthSync else { return "Reading and writing" }
        return "Reading and writing · \(relative(last))"
    }

    private var storageDetail: String {
        let days = Set(summaries.map { Calendar.current.startOfDay(for: $0.day) }).count
        let stored = "\(days) \(days == 1 ? "day" : "days") on this iPhone"
        return engine.isHealthConnected ? "\(stored) · backed up in Apple Health" : "\(stored) · connect Health to keep it after a reinstall"
    }

    private var motionIsOn: Bool {
        PedometerService.isAvailable && (engine.motionStatus == .authorized || engine.motionStatus == .notDetermined)
    }

    private var motionDetail: String {
        if !PedometerService.isAvailable { return "Not available on this device" }
        switch engine.motionStatus {
        case .denied, .restricted: return "Turn on in Settings › Privacy › Motion & Fitness"
        default: return "Counting on this iPhone"
        }
    }

    private func relative(_ date: Date) -> String {
        if Date.now.timeIntervalSince(date) < 60 { return "just now" }
        return date.formatted(.relative(presentation: .named))
    }

    // MARK: Data

    private var goalOptions: [Int] {
        var options = Array(stride(from: 2_000, through: 30_000, by: 500))
        if !options.contains(preferences.dailyGoal) {
            options.append(preferences.dailyGoal)
            options.sort()
        }
        return options
    }

    private var export: CSVExport {
        var byDay: [Date: CSVExport.Row] = [:]
        for summary in summaries {
            let day = Calendar.current.startOfDay(for: summary.day)
            if let existing = byDay[day], existing.steps >= summary.steps { continue }
            byDay[day] = CSVExport.Row(day: day, steps: summary.steps, distanceMeters: summary.distanceMeters, floors: summary.floors, goal: summary.goal)
        }
        return CSVExport(rows: byDay.values.sorted { $0.day < $1.day }, unit: preferences.distanceUnit)
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private extension Color {
    init(rgb: UInt32) { self.init(uiColor: UIColor(rgb: rgb)) }
}
