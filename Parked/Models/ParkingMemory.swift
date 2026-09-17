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

    init(id: UUID = UUID(), parkedAt: Date) {
        self.id = id
        self.parkedAt = parkedAt
    }

    func apply(_ draft: ParkingDetailsDraft) {
        floor = draft.normalizedFloor
        section = draft.normalizedSection
        spot = draft.normalizedSpot
        landmark = draft.normalizedLandmark
        note = draft.normalizedNote
        parkingPhotoData = draft.parkingPhotoData
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

    fileprivate var normalizedFloor: String? { normalized(floor) }
    fileprivate var normalizedSection: String? { normalized(section) }
    fileprivate var normalizedSpot: String? { normalized(spot) }
    fileprivate var normalizedLandmark: String? { normalized(landmark) }
    fileprivate var normalizedNote: String? { normalized(note) }

    private func normalized(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
