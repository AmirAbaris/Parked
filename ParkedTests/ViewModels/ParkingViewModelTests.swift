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

    func testAccurateLocationIsSavedWithItsAccuracy() async throws {
        let context = try makeContext()
        let estimate = makeEstimate(accuracy: 8)
        let locationProvider = TestParkingLocationProvider(initialEstimate: estimate)
        let state = ParkingViewModel(
            modelContext: context,
            now: { self.parkedAt },
            locationProvider: locationProvider
        )

        await state.tapPark().value

        XCTAssertEqual(state.activeMemory?.locationEstimate, estimate)
        XCTAssertEqual(state.locationCaptureState, .saved(horizontalAccuracy: 8))
    }

    func testApproximateLocationIsAcceptedInsteadOfDiscarded() async throws {
        let context = try makeContext()
        let estimate = makeEstimate(accuracy: 850)
        let locationProvider = TestParkingLocationProvider(initialEstimate: estimate)
        let state = ParkingViewModel(
            modelContext: context,
            now: { self.parkedAt },
            locationProvider: locationProvider
        )

        await state.tapPark().value

        XCTAssertEqual(state.activeMemory?.locationEstimate, estimate)
        XCTAssertEqual(state.activeMemory?.horizontalAccuracy, 850)
    }

    func testUnavailableLocationKeepsManualMemoryAndCanRetry() async throws {
        let context = try makeContext()
        let locationProvider = TestParkingLocationProvider()
        let state = ParkingViewModel(
            modelContext: context,
            now: { self.parkedAt },
            locationProvider: locationProvider
        )

        await state.tapPark().value
        locationProvider.fail()

        XCTAssertNotNil(state.activeMemory)
        XCTAssertNil(state.activeMemory?.locationEstimate)
        XCTAssertEqual(state.locationCaptureState, .unavailable)

        state.keepManualParkingMemory()
        XCTAssertEqual(state.locationCaptureState, .manual)

        let recoveredEstimate = makeEstimate(accuracy: 30)
        state.retryLocationCapture()
        locationProvider.send(recoveredEstimate)

        XCTAssertEqual(state.activeMemory?.locationEstimate, recoveredEstimate)
        XCTAssertEqual(state.locationCaptureState, .saved(horizontalAccuracy: 30))
    }

    func testBetterReadingReplacesInitialEstimateDuringCaptureWindow() async throws {
        let context = try makeContext()
        let initialEstimate = makeEstimate(accuracy: 140)
        let improvedEstimate = makeEstimate(accuracy: 18, capturedAtOffset: 2)
        let locationProvider = TestParkingLocationProvider(initialEstimate: initialEstimate)
        let state = ParkingViewModel(
            modelContext: context,
            now: { self.parkedAt },
            locationProvider: locationProvider
        )

        await state.tapPark().value
        locationProvider.send(improvedEstimate)

        XCTAssertEqual(state.activeMemory?.locationEstimate, improvedEstimate)
        XCTAssertEqual(state.locationCaptureState, .saved(horizontalAccuracy: 18))

        let persistedMemory = try XCTUnwrap(
            context.fetch(FetchDescriptor<ParkingMemory>()).first
        )
        XCTAssertEqual(persistedMemory.locationEstimate, improvedEstimate)

        locationProvider.send(makeEstimate(accuracy: 90, capturedAtOffset: 3))
        XCTAssertEqual(state.activeMemory?.locationEstimate, improvedEstimate)
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

    func testSavingDetailsAddsEveryRecallCueAndPhoto() async throws {
        let context = try makeContext()
        let state = ParkingViewModel(modelContext: context, now: { self.parkedAt })
        await state.tapPark().value
        let photoData = Data([0x01, 0x02, 0x03])

        state.beginEditingDetails()
        state.saveDetails(
            ParkingDetailsDraft(
                floor: "B2",
                section: "Abi",
                spot: "C-14",
                landmark: "Kenare asansor",
                note: "Voroodi az khiaboon-e asli",
                parkingPhotoData: photoData
            )
        )

        XCTAssertEqual(state.screen, .active)
        XCTAssertEqual(state.activeMemory?.floor, "B2")
        XCTAssertEqual(state.activeMemory?.section, "Abi")
        XCTAssertEqual(state.activeMemory?.spot, "C-14")
        XCTAssertEqual(state.activeMemory?.landmark, "Kenare asansor")
        XCTAssertEqual(state.activeMemory?.note, "Voroodi az khiaboon-e asli")
        XCTAssertEqual(state.activeMemory?.parkingPhotoData, photoData)
    }

    func testSavingDetailsEditsExistingRecallCuesAndPhoto() async throws {
        let context = try makeContext()
        let state = ParkingViewModel(modelContext: context, now: { self.parkedAt })
        await state.tapPark().value
        state.beginEditingDetails()
        state.saveDetails(ParkingDetailsDraft(floor: "1", parkingPhotoData: Data([0x01])))

        state.beginEditingDetails()
        state.saveDetails(ParkingDetailsDraft(floor: "2", parkingPhotoData: Data([0x02])))

        XCTAssertEqual(state.activeMemory?.floor, "2")
        XCTAssertEqual(state.activeMemory?.parkingPhotoData, Data([0x02]))
        XCTAssertEqual(try context.fetch(FetchDescriptor<ParkingMemory>()).count, 1)
    }

    func testSavingBlankDetailsClearsRecallCuesAndPhoto() async throws {
        let context = try makeContext()
        let state = ParkingViewModel(modelContext: context, now: { self.parkedAt })
        await state.tapPark().value
        state.beginEditingDetails()
        state.saveDetails(
            ParkingDetailsDraft(
                floor: "B2",
                section: "Abi",
                spot: "C-14",
                landmark: "Kenare asansor",
                note: "Nazdik-e khorooji",
                parkingPhotoData: Data([0x01])
            )
        )

        state.beginEditingDetails()
        state.saveDetails(ParkingDetailsDraft(floor: "  ", note: "\n"))

        XCTAssertNil(state.activeMemory?.floor)
        XCTAssertNil(state.activeMemory?.section)
        XCTAssertNil(state.activeMemory?.spot)
        XCTAssertNil(state.activeMemory?.landmark)
        XCTAssertNil(state.activeMemory?.note)
        XCTAssertNil(state.activeMemory?.parkingPhotoData)
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try makeContainer())
    }

    private func makeEstimate(
        accuracy: Double,
        capturedAtOffset: TimeInterval = 0
    ) -> ParkingLocationEstimate {
        ParkingLocationEstimate(
            latitude: 35.7219,
            longitude: 51.3347,
            horizontalAccuracy: accuracy,
            capturedAt: parkedAt.addingTimeInterval(capturedAtOffset)
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: ParkingMemory.self, configurations: configuration)
    }
}

@MainActor
private final class TestParkingLocationProvider: ParkingLocationProviding {
    private let initialEstimate: ParkingLocationEstimate?
    private var onUpdate: ((ParkingLocationEstimate) -> Void)?
    private var onFailure: (() -> Void)?

    init(initialEstimate: ParkingLocationEstimate? = nil) {
        self.initialEstimate = initialEstimate
    }

    func startForegroundCapture(
        onUpdate: @escaping (ParkingLocationEstimate) -> Void,
        onFailure: @escaping () -> Void
    ) -> ParkingLocationEstimate? {
        self.onUpdate = onUpdate
        self.onFailure = onFailure
        return initialEstimate
    }

    func stopForegroundCapture() {
        onUpdate = nil
        onFailure = nil
    }

    func send(_ estimate: ParkingLocationEstimate) {
        onUpdate?(estimate)
    }

    func fail() {
        onFailure?()
    }
}
