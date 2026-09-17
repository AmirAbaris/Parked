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

    init(id: UUID = UUID(), parkedAt: Date) {
        self.id = id
        self.parkedAt = parkedAt
    }
}
