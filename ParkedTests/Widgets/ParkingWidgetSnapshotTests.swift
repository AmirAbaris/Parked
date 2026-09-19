import XCTest
import UIKit
@testable import Parked

final class ParkingWidgetSnapshotTests: XCTestCase {
    func testBuilderPreservesTheThreePrimaryParkingDetailsWithoutAPhoto() {
        let parkingID = UUID(uuidString: "D7EF8343-6684-4719-BE1A-CBD9099C4D65")!
        let parkedAt = Date(timeIntervalSince1970: 1_789_000_000)

        let snapshot = ParkingWidgetSnapshotBuilder.make(
            parkingID: parkingID,
            parkedAt: parkedAt,
            floor: "B2",
            section: "Abi",
            spot: "C-14",
            photoData: nil
        )

        XCTAssertEqual(snapshot.parkingID, parkingID)
        XCTAssertEqual(snapshot.parkedAt, parkedAt)
        XCTAssertEqual(snapshot.floor, "B2")
        XCTAssertEqual(snapshot.section, "Abi")
        XCTAssertEqual(snapshot.spot, "C-14")
        XCTAssertNil(snapshot.photoData)
        XCTAssertFalse(snapshot.hasParkingPhoto)
    }

    func testBuilderOmitsThePhotoReferenceWhenParkingHasNoPhoto() {
        let snapshot = ParkingWidgetSnapshotBuilder.make(
            parkingID: UUID(),
            parkedAt: .now,
            floor: nil,
            section: nil,
            spot: nil,
            photoData: nil
        )

        XCTAssertNil(snapshot.photoData)
        XCTAssertFalse(snapshot.hasParkingPhoto)
    }

    func testBuilderEmbedsADecodableCompactPhotoForTheWidget() throws {
        let sourceImage = UIGraphicsImageRenderer(size: CGSize(width: 2_000, height: 1_000)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2_000, height: 1_000))
            for index in 0 ..< 100 {
                UIColor(
                    hue: CGFloat(index) / 100,
                    saturation: 0.8,
                    brightness: 0.9,
                    alpha: 1
                ).setFill()
                context.fill(CGRect(x: index * 20, y: 0, width: 10, height: 1_000))
            }
        }
        let sourceData = try XCTUnwrap(sourceImage.jpegData(compressionQuality: 1))

        let snapshot = ParkingWidgetSnapshotBuilder.make(
            parkingID: UUID(),
            parkedAt: .now,
            floor: nil,
            section: nil,
            spot: nil,
            photoData: sourceData
        )

        let widgetData = try XCTUnwrap(snapshot.photoData)
        let widgetImage = try XCTUnwrap(UIImage(data: widgetData))
        XCTAssertTrue(snapshot.hasParkingPhoto)
        XCTAssertLessThanOrEqual(max(widgetImage.size.width, widgetImage.size.height), 1_200)
        XCTAssertLessThanOrEqual(widgetData.count, ParkingWidgetSnapshotBuilder.maximumPhotoDataBytes)
    }

    func testFindMyCarRouteOnlyAcceptsTheWidgetDeepLink() {
        XCTAssertTrue(ParkingWidgetRoute.opensFindMyCar(ParkingWidgetRoute.findMyCarURL))
        XCTAssertFalse(ParkingWidgetRoute.opensFindMyCar(ParkingWidgetRoute.appURL))
    }
}
