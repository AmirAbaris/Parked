//
//  ParkingWidgetStore.swift
//  Parked
//

import Foundation
import OSLog
import WidgetKit

enum ParkingWidgetStore {
    static let appGroupIdentifier = "group.aba.Parked"
    static let snapshotKey = "parking-widget-snapshot"
    static let kind = "ParkedWidget"
    private static let logger = Logger(subsystem: "aba.Parked", category: "Widget")

    static func save(_ snapshot: ParkingWidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            logger.error("Could not open the Parked app group for widget data.")
            return
        }

        guard let encodedSnapshot = try? JSONEncoder().encode(snapshot) else {
            logger.error("Could not encode the parking widget snapshot.")
            return
        }

        defaults.set(encodedSnapshot, forKey: snapshotKey)
        guard defaults.synchronize(), defaults.data(forKey: snapshotKey) == encodedSnapshot else {
            logger.error("The parking widget snapshot was not persisted.")
            return
        }
        reloadWidget()
    }

    static func clear() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            logger.error("Could not open the Parked app group to clear widget data.")
            return
        }

        defaults.removeObject(forKey: snapshotKey)
        defaults.synchronize()
        reloadWidget()
    }

    static func read() -> ParkingWidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(ParkingWidgetSnapshot.self, from: data)
    }

    private static func reloadWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}
