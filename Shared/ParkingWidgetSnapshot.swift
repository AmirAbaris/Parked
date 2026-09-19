//
//  ParkingWidgetSnapshot.swift
//  Parked
//

import Foundation

struct ParkingWidgetSnapshot: Codable, Equatable, Sendable {
    let parkingID: UUID
    let parkedAt: Date
    let floor: String?
    let section: String?
    let spot: String?
    let photoFilename: String?

    var hasParkingPhoto: Bool {
        photoFilename != nil
    }
}

enum ParkingWidgetSnapshotBuilder {
    static func make(
        parkingID: UUID,
        parkedAt: Date,
        floor: String?,
        section: String?,
        spot: String?,
        hasParkingPhoto: Bool
    ) -> ParkingWidgetSnapshot {
        ParkingWidgetSnapshot(
            parkingID: parkingID,
            parkedAt: parkedAt,
            floor: floor,
            section: section,
            spot: spot,
            photoFilename: hasParkingPhoto ? "\(parkingID.uuidString).jpg" : nil
        )
    }
}

enum ParkingWidgetRoute {
    static let findMyCarURL = URL(string: "parked://find-my-car")!
    static let appURL = URL(string: "parked://open")!

    static func opensFindMyCar(_ url: URL) -> Bool {
        url.scheme == "parked" && url.host == "find-my-car"
    }
}
