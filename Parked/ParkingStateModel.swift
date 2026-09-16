//
//  ParkingStateModel.swift
//  Parked
//

import Foundation
import Observation
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

@MainActor
@Observable
final class ParkingStateModel {
    enum Screen: Equatable {
        case empty
        case saving
        case active
        case replacementConfirmation
        case completionConfirmation
        case persistenceFailure
    }

    private let modelContext: ModelContext
    private let now: () -> Date

    private(set) var activeMemory: ParkingMemory?
    private(set) var screen: Screen = .empty

    init(modelContext: ModelContext, now: @escaping () -> Date = Date.init) {
        self.modelContext = modelContext
        self.now = now
    }

    func restore() {
        let descriptor = FetchDescriptor<ParkingMemory>(
            sortBy: [SortDescriptor(\ParkingMemory.parkedAt, order: .reverse)]
        )
        let memories: [ParkingMemory]
        do {
            memories = try modelContext.fetch(descriptor)
        } catch {
            activeMemory = nil
            screen = .persistenceFailure
            return
        }

        activeMemory = memories.first
        screen = activeMemory == nil ? .empty : .active

        // The app only has one active parking memory. Clean up any records left
        // behind by an interrupted older build before exposing the active one.
        for staleMemory in memories.dropFirst() {
            modelContext.delete(staleMemory)
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            activeMemory = nil
            screen = .persistenceFailure
        }
    }

    func tapPark() {
        guard activeMemory == nil else {
            screen = .replacementConfirmation
            return
        }
        saveNewMemory()
    }

    func confirmReplacement() {
        guard activeMemory != nil else { return }
        saveNewMemory(replacingActiveMemory: true)
    }

    func cancelConfirmation() {
        screen = activeMemory == nil ? .empty : .active
    }

    func requestCompletion() {
        guard activeMemory != nil else { return }
        screen = .completionConfirmation
    }

    func confirmCompletion() {
        guard let activeMemory else { return }
        modelContext.delete(activeMemory)
        do {
            try modelContext.save()
            self.activeMemory = nil
            screen = .empty
        } catch {
            modelContext.rollback()
            self.activeMemory = activeMemory
            screen = .persistenceFailure
        }
    }

    private func saveNewMemory(replacingActiveMemory: Bool = false) {
        screen = .saving
        let previousMemory = activeMemory
        if replacingActiveMemory, let activeMemory {
            modelContext.delete(activeMemory)
        }

        let memory = ParkingMemory(parkedAt: now())
        modelContext.insert(memory)
        do {
            try modelContext.save()
            activeMemory = memory
            screen = .active
        } catch {
            modelContext.rollback()
            activeMemory = previousMemory
            screen = .persistenceFailure
        }
    }
}
