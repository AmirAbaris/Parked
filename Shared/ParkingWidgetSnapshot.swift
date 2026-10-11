//
//  ParkingWidgetSnapshot.swift
//  Parked
//

import Foundation
import UIKit

struct ParkingWidgetSnapshot: Codable, Equatable, Sendable {
    let parkingID: UUID
    let parkedAt: Date
    let floor: String?
    let section: String?
    let spot: String?
    let photoData: Data?

    var hasParkingPhoto: Bool {
        photoData != nil
    }
}

enum ParkingWidgetSnapshotBuilder {
    static let maximumPhotoDataBytes = 800_000

    static func make(
        parkingID: UUID,
        parkedAt: Date,
        floor: String?,
        section: String?,
        spot: String?,
        photoData: Data?
    ) -> ParkingWidgetSnapshot {
        ParkingWidgetSnapshot(
            parkingID: parkingID,
            parkedAt: parkedAt,
            floor: floor,
            section: section,
            spot: spot,
            // A compact image travels with the snapshot. Keeping it beside the
            // parking details prevents the widget from becoming empty when its
            // separate shared-file lookup has not caught up yet.
            photoData: compactPhotoData(from: photoData)
        )
    }

    private static func compactPhotoData(from data: Data?) -> Data? {
        guard let data, let sourceImage = UIImage(data: data) else { return nil }

        let maximumPixelLength: CGFloat = 1_200
        let minimumPixelLength: CGFloat = 320
        let longestSide = max(sourceImage.size.width, sourceImage.size.height)
        var targetPixelLength = min(maximumPixelLength, longestSide)
        var compressionQuality: CGFloat = 0.82

        while true {
            let scale = targetPixelLength / longestSide
            let targetSize = CGSize(
                width: max(1, sourceImage.size.width * scale),
                height: max(1, sourceImage.size.height * scale)
            )

            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            let image = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
                sourceImage.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            guard let compactData = image.jpegData(compressionQuality: compressionQuality) else { return nil }
            if compactData.count <= maximumPhotoDataBytes || targetPixelLength <= minimumPixelLength {
                return compactData
            }

            targetPixelLength = max(minimumPixelLength, targetPixelLength * 0.75)
            compressionQuality = max(0.5, compressionQuality - 0.08)
        }
    }
}

enum ParkingWidgetRoute {
    static let findMyCarURL = URL(string: "parked://find-my-car")!
    static let appURL = URL(string: "parked://open")!

    static func opensFindMyCar(_ url: URL) -> Bool {
        url.scheme == "parked" && url.host == "find-my-car"
    }
}
