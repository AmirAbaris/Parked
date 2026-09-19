import XCTest
@testable import Parked

final class ParkingWidgetSnapshotTests: XCTestCase {
    func testBuilderPreservesTheThreePrimaryParkingDetailsAndPhotoReference() {
        let parkingID = UUID(uuidString: "D7EF8343-6684-4719-BE1A-CBD9099C4D65")!
        let parkedAt = Date(timeIntervalSince1970: 1_789_000_000)

        let snapshot = ParkingWidgetSnapshotBuilder.make(
            parkingID: parkingID,
            parkedAt: parkedAt,
            floor: "B2",
            section: "Abi",
            spot: "C-14",
            hasParkingPhoto: true
        )

        XCTAssertEqual(snapshot.parkingID, parkingID)
        XCTAssertEqual(snapshot.parkedAt, parkedAt)
        XCTAssertEqual(snapshot.floor, "B2")
        XCTAssertEqual(snapshot.section, "Abi")
        XCTAssertEqual(snapshot.spot, "C-14")
        XCTAssertEqual(snapshot.photoFilename, "D7EF8343-6684-4719-BE1A-CBD9099C4D65.jpg")
    }

    func testBuilderOmitsThePhotoReferenceWhenParkingHasNoPhoto() {
        let snapshot = ParkingWidgetSnapshotBuilder.make(
            parkingID: UUID(),
            parkedAt: .now,
            floor: nil,
            section: nil,
            spot: nil,
            hasParkingPhoto: false
        )

        XCTAssertNil(snapshot.photoFilename)
        XCTAssertFalse(snapshot.hasParkingPhoto)
    }

    func testFindMyCarRouteOnlyAcceptsTheWidgetDeepLink() {
        XCTAssertTrue(ParkingWidgetRoute.opensFindMyCar(ParkingWidgetRoute.findMyCarURL))
        XCTAssertFalse(ParkingWidgetRoute.opensFindMyCar(ParkingWidgetRoute.appURL))
    }
}
