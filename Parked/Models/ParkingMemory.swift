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
    var latitude: Double?
    var longitude: Double?
    var horizontalAccuracy: Double?
    var locationCapturedAt: Date?

    init(
        id: UUID = UUID(),
        parkedAt: Date,
        locationEstimate: ParkingLocationEstimate? = nil
    ) {
        self.id = id
        self.parkedAt = parkedAt
        apply(locationEstimate)
    }

    func apply(_ draft: ParkingDetailsDraft) {
        floor = draft.normalizedFloor
        section = draft.normalizedSection
        spot = draft.normalizedSpot
        landmark = draft.normalizedLandmark
        note = draft.normalizedNote
    }

    func apply(_ estimate: ParkingLocationEstimate?) {
        latitude = estimate?.latitude
        longitude = estimate?.longitude
        horizontalAccuracy = estimate?.horizontalAccuracy
        locationCapturedAt = estimate?.capturedAt
    }

    var locationEstimate: ParkingLocationEstimate? {
        guard let latitude,
              let longitude,
              let horizontalAccuracy,
              let locationCapturedAt else { return nil }

        let estimate = ParkingLocationEstimate(
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracy: horizontalAccuracy,
            capturedAt: locationCapturedAt
        )
        return estimate.isUsable ? estimate : nil
    }
}

struct ParkingLocationEstimate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double
    let capturedAt: Date

    var isUsable: Bool {
        latitude.isFinite
            && longitude.isFinite
            && horizontalAccuracy.isFinite
            && (-90...90).contains(latitude)
            && (-180...180).contains(longitude)
            && horizontalAccuracy >= 0
    }

    func isMoreAccurate(than other: ParkingLocationEstimate) -> Bool {
        horizontalAccuracy < other.horizontalAccuracy
    }

    func distance(to other: ParkingLocationEstimate) -> Double {
        let latitudeDelta = (other.latitude - latitude) * .pi / 180
        let longitudeDelta = (other.longitude - longitude) * .pi / 180
        let currentLatitude = latitude * .pi / 180
        let otherLatitude = other.latitude * .pi / 180
        let arc = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(currentLatitude) * cos(otherLatitude)
            * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        return 6_371_000 * 2 * atan2(sqrt(arc), sqrt(1 - arc))
    }
}

struct ParkingDetailsDraft: Equatable {
    var floor: String
    var section: String
    var spot: String
    var landmark: String
    var note: String

    init(
        floor: String = "",
        section: String = "",
        spot: String = "",
        landmark: String = "",
        note: String = ""
    ) {
        self.floor = floor
        self.section = section
        self.spot = spot
        self.landmark = landmark
        self.note = note
    }

    init(memory: ParkingMemory) {
        self.init(
            floor: memory.floor ?? "",
            section: memory.section ?? "",
            spot: memory.spot ?? "",
            landmark: memory.landmark ?? "",
            note: memory.note ?? ""
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
