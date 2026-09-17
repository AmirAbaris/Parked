//
//  ParkingViewModel.swift
//  Parked
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ParkingViewModel {
    enum Screen: Equatable {
        case empty
        case saving
        case active
        case editing
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

    @discardableResult
    func tapPark() -> Task<Void, Never> {
        guard activeMemory == nil else {
            screen = .replacementConfirmation
            return Task {}
        }
        return saveNewMemory()
    }

    @discardableResult
    func confirmReplacement() -> Task<Void, Never> {
        guard activeMemory != nil else { return Task {} }
        return saveNewMemory(replacingActiveMemory: true)
    }

    func cancelConfirmation() {
        screen = activeMemory == nil ? .empty : .active
    }

    func requestCompletion() {
        guard activeMemory != nil else { return }
        screen = .completionConfirmation
    }

    @discardableResult
    func beginEditingDetails() -> ParkingDetailsDraft? {
        guard let activeMemory else { return nil }
        screen = .editing
        return ParkingDetailsDraft(memory: activeMemory)
    }

    func cancelDetailsEditing() {
        guard activeMemory != nil else { return }
        screen = .active
    }

    func saveDetails(_ draft: ParkingDetailsDraft) {
        guard let activeMemory else { return }

        activeMemory.apply(draft)

        do {
            try modelContext.save()
            screen = .active
        } catch {
            modelContext.rollback()
            screen = .persistenceFailure
        }
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

    private func saveNewMemory(replacingActiveMemory: Bool = false) -> Task<Void, Never> {
        screen = .saving
        let previousMemory = activeMemory
        let parkedAt = now()

        return Task { @MainActor in
            await Task.yield()
            self.persistNewMemory(
                parkedAt: parkedAt,
                previousMemory: previousMemory,
                replacingActiveMemory: replacingActiveMemory
            )
        }
    }

    private func persistNewMemory(
        parkedAt: Date,
        previousMemory: ParkingMemory?,
        replacingActiveMemory: Bool
    ) {
        if replacingActiveMemory, let activeMemory {
            modelContext.delete(activeMemory)
        }

        let memory = ParkingMemory(parkedAt: parkedAt)
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
