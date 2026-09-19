//
//  ParkingMapAvailabilityProvider.swift
//  Parked
//

import Network

@MainActor
protocol ParkingMapAvailabilityProviding: AnyObject {
    @discardableResult
    func startObserving(onChange: @escaping (Bool) -> Void) -> Bool

    func stopObserving()
}

@MainActor
final class NetworkParkingMapAvailabilityProvider: ParkingMapAvailabilityProviding {
    private let queue = DispatchQueue(label: "aba.Parked.map-availability")
    private var monitor: NWPathMonitor?
    private var onChange: ((Bool) -> Void)?

    @discardableResult
    func startObserving(onChange: @escaping (Bool) -> Void) -> Bool {
        stopObserving()

        let monitor = NWPathMonitor()
        self.monitor = monitor
        self.onChange = onChange
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.onChange?(path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
        return monitor.currentPath.status != .unsatisfied
    }

    func stopObserving() {
        monitor?.cancel()
        monitor = nil
        onChange = nil
    }
}
