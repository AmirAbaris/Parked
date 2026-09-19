//
//  SavedParkingMapView.swift
//  Parked
//

import MapKit
import SwiftUI
import UIKit

struct SavedParkingMapView: UIViewRepresentable {
    let location: ParkingLocationEstimate
    let onLoadingFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoadingFailure: onLoadingFailure)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        configure(mapView, using: context.coordinator)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onLoadingFailure = onLoadingFailure
        configure(mapView, using: context.coordinator)
    }

    private func configure(_ mapView: MKMapView, using coordinator: Coordinator) {
        guard coordinator.displayedLocation != location else { return }
        coordinator.displayedLocation = location

        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)

        let annotation = MKPointAnnotation()
        annotation.coordinate = location.coordinate
        annotation.title = "Jaye park"
        mapView.addAnnotation(annotation)

        if location.horizontalAccuracy >= 25 {
            mapView.addOverlay(MKCircle(center: location.coordinate, radius: location.horizontalAccuracy))
        }
        mapView.setRegion(mapRegion(for: location), animated: false)
    }

    private func mapRegion(for location: ParkingLocationEstimate) -> MKCoordinateRegion {
        let span = min(max(location.horizontalAccuracy / 55_000, 0.005), 0.08)
        return MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var displayedLocation: ParkingLocationEstimate?
        var onLoadingFailure: () -> Void

        init(onLoadingFailure: @escaping () -> Void) {
            self.onLoadingFailure = onLoadingFailure
        }

        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
            onLoadingFailure()
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let circle = overlay as? MKCircle else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKCircleRenderer(circle: circle)
            renderer.fillColor = UIColor.tintColor.withAlphaComponent(0.18)
            renderer.strokeColor = UIColor.tintColor.withAlphaComponent(0.7)
            renderer.lineWidth = 1
            return renderer
        }
    }
}

private extension ParkingLocationEstimate {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
