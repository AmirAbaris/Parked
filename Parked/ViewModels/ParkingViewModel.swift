//
//  ParkingViewModel.swift
//  Parked
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ParkingViewModel {
    enum Screen: Equatable {
        case empty
        case saving
        case active
        case editing
        case replacementConfirmation
        case completionConfirmation
        case persistenceFailure
    }

    enum LocationCaptureState: Equatable {
        case idle
        case capturing
        case saved(horizontalAccuracy: Double)
        case unavailable
        case manual
    }

    enum FindMyCarLocationState: Equatable {
        case idle
        case capturing
        case available
        case unavailable
        case recallCuesOnly
    }

    enum MapAvailabilityState: Equatable {
        case available
        case unavailable
    }

    private let modelContext: ModelContext
    private let now: () -> Date
    private let locationProvider: ParkingLocationProviding?
    private let mapAvailabilityProvider: ParkingMapAvailabilityProviding?
    private let locationCaptureWindowNanoseconds: UInt64
    private var locationCaptureWindowTask: Task<Void, Never>?
    private var pendingLocationEstimate: ParkingLocationEstimate?
    private var pendingLocationCaptureFailed = false
    private var isPreparingNewMemory = false
    private var currentFindMyCarLocation: ParkingLocationEstimate?
    private var isFindMyCarViewActive = false

    private(set) var activeMemory: ParkingMemory?
    private(set) var screen: Screen = .empty
    private(set) var locationCaptureState: LocationCaptureState = .idle
    private(set) var findMyCarLocationState: FindMyCarLocationState = .idle
    private(set) var mapAvailabilityState: MapAvailabilityState = .available

    var returnDistanceMeters: Double? {
        guard let savedLocation = activeMemory?.locationEstimate,
              let currentFindMyCarLocation else { return nil }
        return currentFindMyCarLocation.distance(to: savedLocation)
    }

    var returnDistanceDescription: String? {
        guard let returnDistanceMeters else { return nil }
        return Self.metricDistanceDescription(for: returnDistanceMeters)
    }

    var directionsURL: URL? {
        guard mapAvailabilityState == .available,
              let location = activeMemory?.locationEstimate else { return nil }
        return URL(
            string: "http://maps.apple.com/?daddr=\(location.latitude),\(location.longitude)&dirflg=d"
        )
    }

    init(
        modelContext: ModelContext,
        now: @escaping () -> Date = Date.init,
        locationProvider: ParkingLocationProviding? = nil,
        mapAvailabilityProvider: ParkingMapAvailabilityProviding? = nil,
        locationCaptureWindowNanoseconds: UInt64 = 10_000_000_000
    ) {
        self.modelContext = modelContext
        self.now = now
        self.locationProvider = locationProvider
        self.mapAvailabilityProvider = mapAvailabilityProvider
        self.locationCaptureWindowNanoseconds = locationCaptureWindowNanoseconds
    }

    func restore() {
        let descriptor = FetchDescriptor<ParkingMemory>(
            sortBy: [SortDescriptor(\ParkingMemory.parkedAt, order: .reverse)]
        )
        let memories: [ParkingMemory]
        do {
            memories = try modelContext.fetch(descriptor)
        } catch {
            activeMemory = nil
            screen = .persistenceFailure
            return
        }

        activeMemory = memories.first
        screen = activeMemory == nil ? .empty : .active
        locationCaptureState = activeMemory.map(locationState(for:)) ?? .idle

        // The app only has one active parking memory. Clean up any records left
        // behind by an interrupted older build before exposing the active one.
        for staleMemory in memories.dropFirst() {
            modelContext.delete(staleMemory)
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            activeMemory = nil
            screen = .persistenceFailure
        }
    }

    @discardableResult
    func tapPark() -> Task<Void, Never> {
        guard activeMemory == nil else {
            screen = .replacementConfirmation
            return Task {}
        }
        return saveNewMemory()
    }

    @discardableResult
    func confirmReplacement() -> Task<Void, Never> {
        guard activeMemory != nil else { return Task {} }
        return saveNewMemory(replacingActiveMemory: true)
    }

    func cancelConfirmation() {
        screen = activeMemory == nil ? .empty : .active
    }

    func requestCompletion() {
        guard activeMemory != nil else { return }
        screen = .completionConfirmation
    }

    @discardableResult
    func beginEditingDetails() -> ParkingDetailsDraft? {
        guard let activeMemory else { return nil }
        screen = .editing
        return ParkingDetailsDraft(memory: activeMemory)
    }

    func cancelDetailsEditing() {
        guard activeMemory != nil else { return }
        screen = .active
    }

    func saveDetails(_ draft: ParkingDetailsDraft) {
        guard let activeMemory else { return }

        activeMemory.apply(draft)

        do {
            try modelContext.save()
            screen = .active
        } catch {
            modelContext.rollback()
            screen = .persistenceFailure
        }
    }

    func savePhoto(_ data: Data?, for memoryID: UUID) {
        guard let activeMemory, activeMemory.id == memoryID else { return }
        activeMemory.parkingPhotoData = data
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            screen = .persistenceFailure
        }
    }

    func confirmCompletion() {
        guard let activeMemory else { return }
        stopLocationCapture()
        modelContext.delete(activeMemory)
        do {
            try modelContext.save()
            self.activeMemory = nil
            screen = .empty
            locationCaptureState = .idle
        } catch {
            modelContext.rollback()
            self.activeMemory = activeMemory
            screen = .persistenceFailure
        }
    }

    func retryLocationCapture() {
        guard activeMemory != nil else { return }
        beginLocationCapture(preparingNewMemory: false)
        scheduleLocationCaptureWindowEnd()
    }

    func keepManualParkingMemory() {
        guard activeMemory?.locationEstimate == nil else { return }
        stopLocationCapture()
        locationCaptureState = .manual
    }

    func stopLocationCaptureForBackground() {
        if isFindMyCarViewActive {
            stopLocationCapture()
            mapAvailabilityProvider?.stopObserving()
            currentFindMyCarLocation = nil
            findMyCarLocationState = .idle
            mapAvailabilityState = .available
            return
        }
        guard activeMemory != nil || isPreparingNewMemory else { return }
        finishLocationCaptureWindow()
    }

    func resumeFindMyCarAfterForeground() {
        guard isFindMyCarViewActive else { return }
        isFindMyCarViewActive = false
        beginFindMyCar()
    }

    func beginFindMyCar() {
        guard !isFindMyCarViewActive else { return }
        guard let activeMemory else { return }

        isFindMyCarViewActive = true
        currentFindMyCarLocation = nil
        mapAvailabilityState = .available
        guard activeMemory.locationEstimate != nil else {
            findMyCarLocationState = .recallCuesOnly
            return
        }

        startMapAvailabilityMonitoring()
        stopLocationCapture()
        guard let locationProvider else {
            findMyCarLocationState = .unavailable
            return
        }

        findMyCarLocationState = .capturing
        let initialEstimate = locationProvider.startForegroundCapture(
            onUpdate: { [weak self] estimate in
                self?.receiveFindMyCarLocation(estimate)
            },
            onFailure: { [weak self] in
                self?.findMyCarLocationCaptureFailed()
            }
        )
        if let initialEstimate {
            receiveFindMyCarLocation(initialEstimate)
        }
    }

    func endFindMyCar() {
        guard isFindMyCarViewActive else { return }
        stopLocationCapture()
        mapAvailabilityProvider?.stopObserving()
        isFindMyCarViewActive = false
        currentFindMyCarLocation = nil
        findMyCarLocationState = .idle
        mapAvailabilityState = .available
    }

    private func saveNewMemory(replacingActiveMemory: Bool = false) -> Task<Void, Never> {
        screen = .saving
        let previousMemory = activeMemory
        let parkedAt = now()
        beginLocationCapture(preparingNewMemory: true)

        return Task { @MainActor in
            await Task.yield()
            self.persistNewMemory(
                parkedAt: parkedAt,
                previousMemory: previousMemory,
                replacingActiveMemory: replacingActiveMemory
            )
        }
    }

    private func persistNewMemory(
        parkedAt: Date,
        previousMemory: ParkingMemory?,
        replacingActiveMemory: Bool
    ) {
        if replacingActiveMemory, let activeMemory {
            modelContext.delete(activeMemory)
        }

        let memory = ParkingMemory(
            parkedAt: parkedAt,
            locationEstimate: pendingLocationEstimate
        )
        modelContext.insert(memory)
        do {
            try modelContext.save()
            activeMemory = memory
            screen = .active
            isPreparingNewMemory = false
            pendingLocationEstimate = nil
            let captureFailed = pendingLocationCaptureFailed
            pendingLocationCaptureFailed = false
            if captureFailed, memory.locationEstimate == nil {
                locationCaptureState = .unavailable
            } else {
                locationCaptureState = locationStateWhileCapturing(for: memory)
                scheduleLocationCaptureWindowEnd()
            }
        } catch {
            modelContext.rollback()
            activeMemory = previousMemory
            screen = .persistenceFailure
            isPreparingNewMemory = false
            pendingLocationEstimate = nil
            pendingLocationCaptureFailed = false
            stopLocationCapture()
        }
    }

    private func beginLocationCapture(preparingNewMemory: Bool) {
        stopLocationCapture()
        isPreparingNewMemory = preparingNewMemory
        pendingLocationEstimate = nil
        pendingLocationCaptureFailed = false

        guard let locationProvider else {
            locationCaptureState = .manual
            return
        }

        locationCaptureState = .capturing
        let initialEstimate = locationProvider.startForegroundCapture(
            onUpdate: { [weak self] estimate in
                self?.receiveLocationEstimate(estimate)
            },
            onFailure: { [weak self] in
                self?.locationCaptureFailed()
            }
        )
        if let initialEstimate {
            receiveLocationEstimate(initialEstimate)
        }
    }

    private func receiveLocationEstimate(_ estimate: ParkingLocationEstimate) {
        guard estimate.isUsable else { return }

        if isPreparingNewMemory || activeMemory == nil {
            if pendingLocationEstimate.map({ isPreferredInitialEstimate(estimate, over: $0) }) ?? true {
                pendingLocationEstimate = estimate
            }
            locationCaptureState = .saved(horizontalAccuracy: pendingLocationEstimate?.horizontalAccuracy ?? estimate.horizontalAccuracy)
            return
        }

        guard let activeMemory else { return }
        if let savedEstimate = activeMemory.locationEstimate,
           !estimate.isMoreAccurate(than: savedEstimate) {
            locationCaptureState = .saved(horizontalAccuracy: savedEstimate.horizontalAccuracy)
            return
        }

        activeMemory.apply(estimate)
        do {
            try modelContext.save()
            locationCaptureState = .saved(horizontalAccuracy: estimate.horizontalAccuracy)
        } catch {
            modelContext.rollback()
            screen = .persistenceFailure
            stopLocationCapture()
        }
    }

    private func receiveFindMyCarLocation(_ estimate: ParkingLocationEstimate) {
        guard isFindMyCarViewActive, estimate.isUsable else { return }
        currentFindMyCarLocation = estimate
        findMyCarLocationState = .available
    }

    private func findMyCarLocationCaptureFailed() {
        guard isFindMyCarViewActive else { return }
        currentFindMyCarLocation = nil
        findMyCarLocationState = .unavailable
        stopLocationCapture()
    }

    private func startMapAvailabilityMonitoring() {
        guard let mapAvailabilityProvider else { return }
        mapAvailabilityState = mapAvailabilityProvider.startObserving { [weak self] isAvailable in
            guard self?.isFindMyCarViewActive == true else { return }
            self?.mapAvailabilityState = isAvailable ? .available : .unavailable
        } ? .available : .unavailable
    }

    private func locationCaptureFailed() {
        if isPreparingNewMemory {
            guard pendingLocationEstimate == nil else { return }
            pendingLocationCaptureFailed = true
            locationCaptureState = .unavailable
            stopLocationCapture()
            return
        }

        guard pendingLocationEstimate == nil,
              activeMemory?.locationEstimate == nil else { return }
        locationCaptureState = .unavailable
        stopLocationCapture()
    }

    private func scheduleLocationCaptureWindowEnd() {
        guard locationProvider != nil else { return }
        locationCaptureWindowTask?.cancel()
        locationCaptureWindowTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: locationCaptureWindowNanoseconds)
            guard !Task.isCancelled else { return }
            finishLocationCaptureWindow()
        }
    }

    private func finishLocationCaptureWindow() {
        if isPreparingNewMemory {
            stopLocationCapture()
            if let pendingLocationEstimate {
                locationCaptureState = .saved(
                    horizontalAccuracy: pendingLocationEstimate.horizontalAccuracy
                )
            } else {
                pendingLocationCaptureFailed = true
                locationCaptureState = .unavailable
            }
            return
        }

        let memory = activeMemory
        stopLocationCapture()
        locationCaptureState = memory.map(locationState(for:)) ?? .idle
        if locationCaptureState == .manual {
            locationCaptureState = .unavailable
        }
    }

    private func stopLocationCapture() {
        locationCaptureWindowTask?.cancel()
        locationCaptureWindowTask = nil
        locationProvider?.stopForegroundCapture()
    }

    private func locationState(for memory: ParkingMemory) -> LocationCaptureState {
        if let estimate = memory.locationEstimate {
            return .saved(horizontalAccuracy: estimate.horizontalAccuracy)
        }
        return .manual
    }

    private func locationStateWhileCapturing(for memory: ParkingMemory) -> LocationCaptureState {
        if let estimate = memory.locationEstimate {
            return .saved(horizontalAccuracy: estimate.horizontalAccuracy)
        }
        return locationProvider == nil ? .manual : .capturing
    }

    private func isPreferredInitialEstimate(
        _ candidate: ParkingLocationEstimate,
        over current: ParkingLocationEstimate
    ) -> Bool {
        if candidate.capturedAt == current.capturedAt {
            return candidate.isMoreAccurate(than: current)
        }
        return candidate.capturedAt > current.capturedAt
    }

    private static func metricDistanceDescription(for meters: Double) -> String {
        if meters < 1_000 {
            let roundedMeters = Int((meters / 10).rounded() * 10)
            return "\(roundedMeters) m"
        }
        return String(format: "%.1f km", meters / 1_000)
    }

}
