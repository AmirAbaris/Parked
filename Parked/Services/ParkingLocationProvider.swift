import CoreLocation
import Foundation

@MainActor
protocol ParkingLocationProviding: AnyObject {
    @discardableResult
    func startForegroundCapture(
        onUpdate: @escaping (ParkingLocationEstimate) -> Void,
        onFailure: @escaping () -> Void
    ) -> ParkingLocationEstimate?

    func stopForegroundCapture()
}

@MainActor
final class CoreLocationParkingLocationProvider: NSObject, ParkingLocationProviding {
    private static let maximumCachedLocationAge: TimeInterval = 30

    private let locationManager: CLLocationManager
    private var onUpdate: ((ParkingLocationEstimate) -> Void)?
    private var onFailure: (() -> Void)?

    override init() {
        locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = false
    }

    @discardableResult
    func startForegroundCapture(
        onUpdate: @escaping (ParkingLocationEstimate) -> Void,
        onFailure: @escaping () -> Void
    ) -> ParkingLocationEstimate? {
        self.onUpdate = onUpdate
        self.onFailure = onFailure

        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            Task { @MainActor [weak self] in
                self?.onFailure?()
            }
        @unknown default:
            Task { @MainActor [weak self] in
                self?.onFailure?()
            }
        }

        return locationManager.location.flatMap(Self.currentEstimate(from:))
    }

    func stopForegroundCapture() {
        locationManager.stopUpdatingLocation()
        onUpdate = nil
        onFailure = nil
    }

    private static func currentEstimate(from location: CLLocation) -> ParkingLocationEstimate? {
        let age = Date().timeIntervalSince(location.timestamp)
        guard age >= -5, age <= maximumCachedLocationAge else { return nil }

        let estimate = ParkingLocationEstimate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy,
            capturedAt: location.timestamp
        )
        return estimate.isUsable ? estimate : nil
    }
}

extension CoreLocationParkingLocationProvider: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            onFailure?()
        case .notDetermined:
            break
        @unknown default:
            onFailure?()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let estimate = locations
            .compactMap(Self.currentEstimate(from:))
            .max(by: { $0.capturedAt < $1.capturedAt }) else { return }
        onUpdate?(estimate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let locationError = error as? CLError, locationError.code == .locationUnknown {
            return
        }
        onFailure?()
    }
}
