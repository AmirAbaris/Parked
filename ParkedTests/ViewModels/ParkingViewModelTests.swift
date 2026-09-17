import SwiftData
import XCTest
@testable import Parked

@MainActor
final class ParkingViewModelTests: XCTestCase {
    private let parkedAt = Date(timeIntervalSince1970: 1_789_000_000)

    func testTapParkCreatesAndPersistsAManualMemoryAtTapTime() async throws {
        let context = try makeContext()
        let state = ParkingViewModel(modelContext: context, now: { self.parkedAt })

        let saveTask = state.tapPark()

        XCTAssertEqual(state.screen, .saving)
        await saveTask.value

        XCTAssertEqual(state.screen, .active)
        XCTAssertEqual(state.activeMemory?.parkedAt, parkedAt)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ParkingMemory>()).count, 1)
    }

    func testRestoreLoadsThePersistedActiveMemory() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memory = ParkingMemory(parkedAt: parkedAt)
        context.insert(memory)
        try context.save()
        let relaunchedContext = ModelContext(container)
        let state = ParkingViewModel(modelContext: relaunchedContext)

        state.restore()

        XCTAssertEqual(state.screen, .active)
        XCTAssertEqual(state.activeMemory?.id, memory.id)
    }

    func testReplacementRequiresConfirmationAndKeepsOnlyTheNewMemory() async throws {
        let context = try makeContext()
        let firstDate = parkedAt
        let replacementDate = parkedAt.addingTimeInterval(60)
        var date = firstDate
        let state = ParkingViewModel(modelContext: context, now: { date })
        await state.tapPark().value
        let firstMemoryID = try XCTUnwrap(state.activeMemory?.id)

        date = replacementDate
        state.tapPark()
        XCTAssertEqual(state.screen, .replacementConfirmation)
        XCTAssertEqual(state.activeMemory?.id, firstMemoryID)

        let replacementTask = state.confirmReplacement()

        XCTAssertEqual(state.screen, .saving)
        await replacementTask.value

        XCTAssertEqual(state.screen, .active)
        XCTAssertEqual(state.activeMemory?.parkedAt, replacementDate)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ParkingMemory>()).count, 1)
    }

    func testCompletionRequiresConfirmationThenRemovesTheMemory() async throws {
        let context = try makeContext()
        let state = ParkingViewModel(modelContext: context, now: { self.parkedAt })
        await state.tapPark().value

        state.requestCompletion()
        XCTAssertEqual(state.screen, .completionConfirmation)
        XCTAssertNotNil(state.activeMemory)

        state.confirmCompletion()

        XCTAssertEqual(state.screen, .empty)
        XCTAssertNil(state.activeMemory)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ParkingMemory>()).isEmpty)
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try makeContainer())
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: ParkingMemory.self, configurations: configuration)
    }
}
