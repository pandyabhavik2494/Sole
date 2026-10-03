import CoreMotion
import Foundation

/// A pedometer reading copied out of `CMPedometerData`.
struct PedometerReading: Sendable {
    var start: Date
    var end: Date
    var steps: Int
    var distanceMeters: Double
    var floorsAscended: Int
}

/// Wraps CMPedometer: the iPhone's motion coprocessor, which counts steps all day and keeps
/// 7 days of history even when Sole isn't running.
///
/// Main-actor isolated so the CMPedometer is only touched from one thread. Its callbacks arrive on
/// a CoreMotion queue, so they are marked `@Sendable` and hop back explicitly.
@MainActor
final class PedometerService {
    struct NoData: Error {}


    private let pedometer = CMPedometer()

    nonisolated static var isAvailable: Bool { CMPedometer.isStepCountingAvailable() }
    nonisolated static var authorizationStatus: CMAuthorizationStatus { CMPedometer.authorizationStatus() }

    /// How far back the motion coprocessor keeps history.
    nonisolated static let historyLimit: TimeInterval = 7 * 24 * 60 * 60

    /// Steps between two times. The first call shows the Motion & Fitness permission prompt.
    func reading(from start: Date, to end: Date) async throws -> PedometerReading {
        try await withCheckedThrowingContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { @Sendable data, error in
                if let data {
                    continuation.resume(returning: PedometerReading(data))
                } else {
                    continuation.resume(throwing: error ?? NoData())
                }
            }
        }
    }

    /// Delivers today's running total each time the coprocessor reports new steps.
    func startLiveUpdates(from start: Date, handler: @escaping @MainActor (PedometerReading) -> Void) {
        guard Self.isAvailable else { return }
        pedometer.startUpdates(from: start) { @Sendable data, _ in
            guard let data else { return }
            let reading = PedometerReading(data)
            Task { @MainActor in handler(reading) }
        }
    }

    func stopLiveUpdates() {
        pedometer.stopUpdates()
    }
}

private extension PedometerReading {
    init(_ data: CMPedometerData) {
        self.init(
            start: data.startDate,
            end: data.endDate,
            steps: data.numberOfSteps.intValue,
            distanceMeters: data.distance?.doubleValue ?? 0,
            floorsAscended: data.floorsAscended?.intValue ?? 0
        )
    }
}
