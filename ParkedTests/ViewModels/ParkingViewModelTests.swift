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

    func testNewestUsableReadingWinsBeforeTheImmediateSave() async throws {
        let context = try makeContext()
        let olderAccurateEstimate = makeEstimate(accuracy: 5)
        let newerApproximateEstimate = makeEstimate(accuracy: 400, capturedAtOffset: 1)
        let locationProvider = TestParkingLocationProvider(
            initialEstimate: olderAccurateEstimate
        )
        let state = ParkingViewModel(
            modelContext: context,
            now: { self.parkedAt },
            locationProvider: locationProvider
        )

        let saveTask = state.tapPark()
        locationProvider.send(newerApproximateEstimate)
        await saveTask.value

        XCTAssertEqual(state.activeMemory?.locationEstimate, newerApproximateEstimate)
    }

    func testReplacementCaptureFailureUsesRecoveryStateInsteadOfOldLocation() async throws {
        let context = try makeContext()
        let locationProvider = TestParkingLocationProvider(
            initialEstimate: makeEstimate(accuracy: 12)
        )
        let state = ParkingViewModel(
            modelContext: context,
            now: { self.parkedAt },
            locationProvider: locationProvider
        )
        await state.tapPark().value

        locationProvider.initialEstimate = nil
        state.tapPark()
        let replacementTask = state.confirmReplacement()
        locationProvider.fail()
        await replacementTask.value

        XCTAssertNil(state.activeMemory?.locationEstimate)
        XCTAssertEqual(state.locationCaptureState, .unavailable)
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

    func testSavingParkingMemoryRequestsSuccessFeedback() async throws {
        let context = try makeContext()
        let state = ParkingViewModel(modelContext: context, now: { self.parkedAt })

        XCTAssertEqual(state.parkingSaveFeedbackCount, 0)

        await state.tapPark().value

        XCTAssertEqual(state.parkingSaveFeedbackCount, 1)
    }

    func testDestructiveConfirmationsRequestWarningFeedback() async throws {
        let context = try makeContext()
        let state = ParkingViewModel(modelContext: context, now: { self.parkedAt })
        await state.tapPark().value

        state.requestCompletion()
        XCTAssertEqual(state.destructiveActionFeedbackCount, 1)

        state.cancelConfirmation()
        state.tapPark()
        XCTAssertEqual(state.destructiveActionFeedbackCount, 2)
    }

    func testRemovingParkingPhotoRequestsWarningFeedback() async throws {
        let context = try makeContext()
        let state = ParkingViewModel(modelContext: context, now: { self.parkedAt })
        await state.tapPark().value
        let memoryID = try XCTUnwrap(state.activeMemory?.id)
        state.savePhoto(Data([0x01]), for: memoryID)

        state.savePhoto(nil, for: memoryID)

        XCTAssertEqual(state.destructiveActionFeedbackCount, 1)
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

    func testSavingDetailsPreservesIndependentlySavedPhoto() async throws {
        let context = try makeContext()
        let state = ParkingViewModel(modelContext: context, now: { self.parkedAt })
        await state.tapPark().value
        let photoData = Data([0x01, 0x02, 0x03])
        state.savePhoto(photoData, for: try XCTUnwrap(state.activeMemory).id)

        state.beginEditingDetails()
        state.saveDetails(
            ParkingDetailsDraft(
                floor: "B2",
                section: "Abi",
                spot: "C-14",
                landmark: "Kenare asansor",
                note: "Voroodi az khiaboon-e asli"
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
        state.saveDetails(ParkingDetailsDraft(floor: "1"))
        let memoryID = try XCTUnwrap(state.activeMemory).id
        state.savePhoto(Data([0x01]), for: memoryID)

        state.beginEditingDetails()
        state.saveDetails(ParkingDetailsDraft(floor: "2"))
        state.savePhoto(Data([0x02]), for: memoryID)

        XCTAssertEqual(state.activeMemory?.floor, "2")
        XCTAssertEqual(state.activeMemory?.parkingPhotoData, Data([0x02]))
        XCTAssertEqual(try context.fetch(FetchDescriptor<ParkingMemory>()).count, 1)
    }

    func testSavingBlankDetailsClearsRecallCuesButPreservesPhoto() async throws {
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
                note: "Nazdik-e khorooji"
            )
        )

        state.savePhoto(Data([0x01]), for: try XCTUnwrap(state.activeMemory).id)
        state.beginEditingDetails()
        state.saveDetails(ParkingDetailsDraft(floor: "  ", note: "\n"))

        XCTAssertNil(state.activeMemory?.floor)
        XCTAssertNil(state.activeMemory?.section)
        XCTAssertNil(state.activeMemory?.spot)
        XCTAssertNil(state.activeMemory?.landmark)
        XCTAssertNil(state.activeMemory?.note)
        XCTAssertEqual(state.activeMemory?.parkingPhotoData, Data([0x01]))
    }

    func testPhotoChangesPersistWithoutChangingDetails() async throws {
        let context = try makeContext()
        let state = ParkingViewModel(modelContext: context)
        await state.tapPark().value
        let memoryID = try XCTUnwrap(state.activeMemory).id
        state.saveDetails(ParkingDetailsDraft(floor: "B2", note: "Kenare asansor"))

        state.savePhoto(Data([0x01]), for: memoryID)
        state.restore()
        XCTAssertEqual(state.screen, .active)
        XCTAssertEqual(state.activeMemory?.parkingPhotoData, Data([0x01]))
        XCTAssertEqual(state.activeMemory?.floor, "B2")

        state.savePhoto(nil, for: memoryID)
        state.restore()
        XCTAssertNil(state.activeMemory?.parkingPhotoData)
        XCTAssertEqual(state.activeMemory?.note, "Kenare asansor")
    }

    func testDelayedPhotoCannotAttachToReplacementMemory() async throws {
        let state = ParkingViewModel(modelContext: try makeContext())
        await state.tapPark().value
        let oldID = try XCTUnwrap(state.activeMemory).id
        await state.confirmReplacement().value

        state.savePhoto(Data([0x01]), for: oldID)

        XCTAssertNil(state.activeMemory?.parkingPhotoData)
        XCTAssertEqual(state.screen, .active)
    }

    func testFindMyCarLocationBackedMemoryUpdatesDistanceAndOffersDirections() async throws {
        let context = try makeContext()
        let savedEstimate = makeEstimate(accuracy: 35)
        let currentEstimate = ParkingLocationEstimate(
            latitude: 35.7319,
            longitude: 51.3347,
            horizontalAccuracy: 12,
            capturedAt: parkedAt
        )
        let locationProvider = TestParkingLocationProvider(initialEstimate: savedEstimate)
        let state = ParkingViewModel(
            modelContext: context,
            now: { self.parkedAt },
            locationProvider: locationProvider
        )
        await state.tapPark().value

        state.beginFindMyCar()
        locationProvider.send(currentEstimate)

        XCTAssertEqual(state.findMyCarLocationState, .available)
        XCTAssertEqual(try XCTUnwrap(state.returnDistanceMeters), 1_111.95, accuracy: 0.5)
        XCTAssertEqual(state.returnDistanceDescription, "1.1 km")
        XCTAssertNotNil(state.directionsURL)
        XCTAssertEqual(locationProvider.startCount, 2)
    }

    func testFindMyCarManualMemoryShowsRecallCuesOnlyAndDoesNotStartLocation() async throws {
        let context = try makeContext()
        let locationProvider = TestParkingLocationProvider()
        let state = ParkingViewModel(
            modelContext: context,
            now: { self.parkedAt },
            locationProvider: locationProvider
        )
        await state.tapPark().value
        locationProvider.fail()
        state.keepManualParkingMemory()
        let startsBeforeFindMyCar = locationProvider.startCount

        state.beginFindMyCar()

        XCTAssertEqual(state.findMyCarLocationState, .recallCuesOnly)
        XCTAssertNil(state.returnDistanceMeters)
        XCTAssertNil(state.directionsURL)
        XCTAssertEqual(locationProvider.startCount, startsBeforeFindMyCar)
    }

    func testFindMyCarLocationFailureKeepsDirectionsAndSavedMemoryAvailable() async throws {
        let context = try makeContext()
        let savedEstimate = makeEstimate(accuracy: 600)
        let locationProvider = TestParkingLocationProvider(initialEstimate: savedEstimate)
        let state = ParkingViewModel(
            modelContext: context,
            now: { self.parkedAt },
            locationProvider: locationProvider
        )
        await state.tapPark().value

        state.beginFindMyCar()
        locationProvider.fail()

        XCTAssertEqual(state.findMyCarLocationState, .unavailable)
        XCTAssertNil(state.returnDistanceMeters)
        XCTAssertNotNil(state.activeMemory)
        XCTAssertNotNil(state.directionsURL)
    }

    func testLeavingFindMyCarAndEnteringBackgroundStopsCurrentLocationUpdates() async throws {
        let context = try makeContext()
        let locationProvider = TestParkingLocationProvider(initialEstimate: makeEstimate(accuracy: 10))
        let state = ParkingViewModel(
            modelContext: context,
            now: { self.parkedAt },
            locationProvider: locationProvider
        )
        await state.tapPark().value

        state.beginFindMyCar()
        let stopsBeforeLeaving = locationProvider.stopCount
        state.endFindMyCar()

        XCTAssertEqual(locationProvider.stopCount, stopsBeforeLeaving + 1)

        state.beginFindMyCar()
        let stopsBeforeBackground = locationProvider.stopCount
        state.stopLocationCaptureForBackground()

        XCTAssertEqual(locationProvider.stopCount, stopsBeforeBackground + 1)
        XCTAssertEqual(state.findMyCarLocationState, .idle)

        let startsBeforeForeground = locationProvider.startCount
        state.resumeFindMyCarAfterForeground()

        XCTAssertEqual(locationProvider.startCount, startsBeforeForeground + 1)
        XCTAssertEqual(state.findMyCarLocationState, .available)
    }

    func testFindMyCarHidesMapAndDirectionsWhenNetworkIsUnavailable() async throws {
        let context = try makeContext()
        let locationProvider = TestParkingLocationProvider(initialEstimate: makeEstimate(accuracy: 20))
        let mapAvailabilityProvider = TestParkingMapAvailabilityProvider(isAvailable: true)
        let state = ParkingViewModel(
            modelContext: context,
            now: { self.parkedAt },
            locationProvider: locationProvider,
            mapAvailabilityProvider: mapAvailabilityProvider
        )
        await state.tapPark().value

        state.beginFindMyCar()
        mapAvailabilityProvider.send(isAvailable: false)

        XCTAssertEqual(state.mapAvailabilityState, .unavailable)
        XCTAssertNil(state.directionsURL)
        XCTAssertNotNil(state.activeMemory)
    }

    func testFindMyCarHidesMapAndDirectionsWhenMapTilesFailToLoad() async throws {
        let context = try makeContext()
        let locationProvider = TestParkingLocationProvider(initialEstimate: makeEstimate(accuracy: 20))
        let state = ParkingViewModel(
            modelContext: context,
            now: { self.parkedAt },
            locationProvider: locationProvider
        )
        await state.tapPark().value

        state.beginFindMyCar()
        state.mapDidFailToLoad()

        XCTAssertEqual(state.mapAvailabilityState, .unavailable)
        XCTAssertNil(state.directionsURL)
        XCTAssertNotNil(state.activeMemory)
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
    var initialEstimate: ParkingLocationEstimate?
    private var onUpdate: ((ParkingLocationEstimate) -> Void)?
    private var onFailure: (() -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(initialEstimate: ParkingLocationEstimate? = nil) {
        self.initialEstimate = initialEstimate
    }

    func startForegroundCapture(
        onUpdate: @escaping (ParkingLocationEstimate) -> Void,
        onFailure: @escaping () -> Void
    ) -> ParkingLocationEstimate? {
        startCount += 1
        self.onUpdate = onUpdate
        self.onFailure = onFailure
        return initialEstimate
    }

    func stopForegroundCapture() {
        stopCount += 1
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

@MainActor
private final class TestParkingMapAvailabilityProvider: ParkingMapAvailabilityProviding {
    private let isAvailable: Bool
    private var onChange: ((Bool) -> Void)?

    init(isAvailable: Bool) {
        self.isAvailable = isAvailable
    }

    func startObserving(onChange: @escaping (Bool) -> Void) -> Bool {
        self.onChange = onChange
        return isAvailable
    }

    func stopObserving() {
        onChange = nil
    }

    func send(isAvailable: Bool) {
        onChange?(isAvailable)
    }
}
