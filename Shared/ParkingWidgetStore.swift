//
//  ParkingWidgetStore.swift
//  Parked
//

import Foundation
import WidgetKit

enum ParkingWidgetStore {
    static let appGroupIdentifier = "group.aba.Parked"
    static let snapshotKey = "parking-widget-snapshot"
    static let kind = "ParkedWidget"

    static func save(_ snapshot: ParkingWidgetSnapshot, photoData: Data?) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        let previousSnapshot = read()
        if previousSnapshot?.photoFilename != snapshot.photoFilename {
            removePhoto(named: previousSnapshot?.photoFilename)
        }
        write(photoData, named: snapshot.photoFilename)
        guard let encodedSnapshot = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(encodedSnapshot, forKey: snapshotKey)
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }

    static func clear() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        if let snapshot = read() {
            removePhoto(named: snapshot.photoFilename)
        }
        defaults.removeObject(forKey: snapshotKey)
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }

    static func read() -> ParkingWidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(ParkingWidgetSnapshot.self, from: data)
    }

    static func photoData(named filename: String?) -> Data? {
        guard let photoURL = photoURL(named: filename) else { return nil }
        return try? Data(contentsOf: photoURL)
    }

    private static func write(_ photoData: Data?, named filename: String?) {
        guard let filename else { return }
        guard let photoData else {
            removePhoto(named: filename)
            return
        }
        guard let photoURL = photoURL(named: filename) else { return }
        try? photoData.write(to: photoURL, options: .atomic)
    }

    private static func removePhoto(named filename: String?) {
        guard let photoURL = photoURL(named: filename) else { return }
        try? FileManager.default.removeItem(at: photoURL)
    }

    private static func photoURL(named filename: String?) -> URL? {
        guard let filename,
              let directory = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier
              ) else { return nil }
        return directory.appending(path: filename)
    }
}
