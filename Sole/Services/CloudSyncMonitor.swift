import CoreData
import Foundation
import Observation

/// Watches the iCloud sync that SwiftData runs for Sole's store, for the status shown in Settings.
@MainActor
@Observable
final class CloudSyncMonitor {
    private(set) var lastSync: Date?
    private(set) var lastError: String?

    /// Called after changes from another device arrive.
    @ObservationIgnored var onImport: (() -> Void)?
    @ObservationIgnored private var observer: NSObjectProtocol?

    private static let lastSyncKey = "lastICloudSync"

    var isSignedIn: Bool { FileManager.default.ubiquityIdentityToken != nil }

    init() {
        lastSync = UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event,
                  let endDate = event.endDate
            else { return }
            let succeeded = event.succeeded
            let type = event.type
            let message = event.error?.localizedDescription
            MainActor.assumeIsolated {
                self?.record(type: type, succeeded: succeeded, endDate: endDate, error: message)
            }
        }
    }

    private func record(type: NSPersistentCloudKitContainer.EventType, succeeded: Bool, endDate: Date, error: String?) {
        guard succeeded else {
            lastError = error
            return
        }
        lastError = nil
        if type == .import || type == .export {
            lastSync = endDate
            UserDefaults.standard.set(endDate, forKey: Self.lastSyncKey)
        }
        if type == .import {
            onImport?()
        }
    }
}
