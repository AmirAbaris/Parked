import SwiftData
import XCTest
@testable import Parked

@MainActor
final class ParkingStateModelTests: XCTestCase {
    private let parkedAt = Date(timeIntervalSince1970: 1_789_000_000)

    func testTapParkCreatesAndPersistsAManualMemoryAtTapTime() throws {
        let context = try makeContext()
        let state = ParkingStateModel(modelContext: context, now: { self.parkedAt })

        state.tapPark()

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
        let state = ParkingStateModel(modelContext: relaunchedContext)

        state.restore()

        XCTAssertEqual(state.screen, .active)
        XCTAssertEqual(state.activeMemory?.id, memory.id)
    }

    func testReplacementRequiresConfirmationAndKeepsOnlyTheNewMemory() throws {
        let context = try makeContext()
        let firstDate = parkedAt
        let replacementDate = parkedAt.addingTimeInterval(60)
        var date = firstDate
        let state = ParkingStateModel(modelContext: context, now: { date })
        state.tapPark()
        let firstMemoryID = try XCTUnwrap(state.activeMemory?.id)

        date = replacementDate
        state.tapPark()
        XCTAssertEqual(state.screen, .replacementConfirmation)
        XCTAssertEqual(state.activeMemory?.id, firstMemoryID)

        state.confirmReplacement()

        XCTAssertEqual(state.screen, .active)
        XCTAssertEqual(state.activeMemory?.parkedAt, replacementDate)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ParkingMemory>()).count, 1)
    }

    func testCompletionRequiresConfirmationThenRemovesTheMemory() throws {
        let context = try makeContext()
        let state = ParkingStateModel(modelContext: context, now: { self.parkedAt })
        state.tapPark()

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
