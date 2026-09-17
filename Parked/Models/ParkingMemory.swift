//
//  ParkingMemory.swift
//  Parked
//

import Foundation
import SwiftData

@Model
final class ParkingMemory {
    @Attribute(.unique) var id: UUID
    var parkedAt: Date
    var floor: String?
    var section: String?
    var spot: String?
    var landmark: String?
    var note: String?
    @Attribute(.externalStorage) var parkingPhotoData: Data?

    init(
        id: UUID = UUID(),
        parkedAt: Date,
        floor: String? = nil,
        section: String? = nil,
        spot: String? = nil,
        landmark: String? = nil,
        note: String? = nil,
        parkingPhotoData: Data? = nil
    ) {
        self.id = id
        self.parkedAt = parkedAt
        self.floor = floor
        self.section = section
        self.spot = spot
        self.landmark = landmark
        self.note = note
        self.parkingPhotoData = parkingPhotoData
    }
}

struct ParkingDetailsDraft: Equatable {
    var floor: String
    var section: String
    var spot: String
    var landmark: String
    var note: String
    var parkingPhotoData: Data?

    init(
        floor: String = "",
        section: String = "",
        spot: String = "",
        landmark: String = "",
        note: String = "",
        parkingPhotoData: Data? = nil
    ) {
        self.floor = floor
        self.section = section
        self.spot = spot
        self.landmark = landmark
        self.note = note
        self.parkingPhotoData = parkingPhotoData
    }

    init(memory: ParkingMemory) {
        self.init(
            floor: memory.floor ?? "",
            section: memory.section ?? "",
            spot: memory.spot ?? "",
            landmark: memory.landmark ?? "",
            note: memory.note ?? "",
            parkingPhotoData: memory.parkingPhotoData
        )
    }
}
