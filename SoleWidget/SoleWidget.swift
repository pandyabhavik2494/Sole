import CoreMotion
import SwiftUI
import WidgetKit

@main
struct SoleWidgetBundle: WidgetBundle {
    var body: some Widget {
        StepsWidget()
    }
}

struct StepsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StepsWidget", provider: StepsProvider()) { entry in
            StepsWidgetView(entry: entry)
                .containerBackground(Palette.surface, for: .widget)
        }
        .configurationDisplayName("Today's steps")
        .description("Your step count and progress toward your daily goal.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct StepsEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot
}

/// Shows the numbers the app last saved, topped up with a fresh read of the iPhone's motion sensor
/// so the widget keeps moving between app launches.
struct StepsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StepsEntry {
        StepsEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StepsEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            currentEntry(completion: completion)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepsEntry>) -> Void) {
        currentEntry { entry in
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: entry.date) ?? entry.date
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func currentEntry(completion: @escaping (StepsEntry) -> Void) {
        let now = Date.now
        let today = Calendar.current.startOfDay(for: now)
        var snapshot = WidgetSnapshot.load() ?? WidgetSnapshot(day: today, steps: 0, distanceMeters: 0, floors: 0, goal: 8_000, unit: .localeDefault, updatedAt: now)
        if snapshot.day != today {
            snapshot.day = today
            snapshot.steps = 0
            snapshot.distanceMeters = 0
            snapshot.floors = 0
        }

        guard CMPedometer.isStepCountingAvailable(), CMPedometer.authorizationStatus() == .authorized else {
            completion(StepsEntry(date: now, snapshot: snapshot))
            return
        }
        // The app's number can include Apple Watch steps, so the sensor only ever raises it.
        let pedometer = CMPedometer()
        pedometer.queryPedometerData(from: today, to: now) { data, _ in
            _ = pedometer
            if let data {
                snapshot.steps = max(snapshot.steps, data.numberOfSteps.intValue)
                snapshot.distanceMeters = max(snapshot.distanceMeters, data.distance?.doubleValue ?? 0)
                snapshot.floors = max(snapshot.floors, data.floorsAscended?.intValue ?? 0)
            }
            completion(StepsEntry(date: now, snapshot: snapshot))
        }
    }
}
