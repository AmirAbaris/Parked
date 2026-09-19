//
//  ContentView.swift
//  Parked
//
//  Created by Amir Abaris on 9/16/26.
//

import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var parkingViewModel: ParkingViewModel?

    var body: some View {
        Group {
            if let parkingViewModel {
                ParkingHomeView(viewModel: parkingViewModel)
            } else {
                ProgressView()
            }
        }
        .task {
            guard parkingViewModel == nil else { return }
            let viewModel = ParkingViewModel(
                modelContext: modelContext,
                locationProvider: CoreLocationParkingLocationProvider(),
                mapAvailabilityProvider: NetworkParkingMapAvailabilityProvider()
            )
            viewModel.restore()
            parkingViewModel = viewModel
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                parkingViewModel?.stopLocationCaptureForBackground()
            } else if newPhase == .active {
                parkingViewModel?.resumeFindMyCarAfterForeground()
            }
        }
    }
}

private struct ParkingHomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var viewModel: ParkingViewModel
    @State private var detailsDraft: ParkingDetailsDraft?
    @State private var isShowingPhotoChoices = false

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.screen {
                case .empty:
                    emptyState
                case .saving:
                    ProgressView("Darim save mikonim…")
                case .active, .editing, .replacementConfirmation, .completionConfirmation:
                    activeState
                case .persistenceFailure:
                    persistenceFailureState
                }
            }
            .navigationTitle("Parked")
            .navigationBarTitleDisplayMode(.large)
            .alert("Park-e ghabli avaz beshe?", isPresented: alertBinding(for: .replacementConfirmation)) {
                Button("Avaz kon", role: .destructive) {
                    viewModel.confirmReplacement()
                }
                Button("Na", role: .cancel) {
                    viewModel.cancelConfirmation()
                }
            } message: {
                Text("Aks o detail-e park-e ghabli pak mishe.")
            }
            .alert("Mashineto peyda kardi?", isPresented: alertBinding(for: .completionConfirmation)) {
                Button("Are, peydash kardam", role: .destructive) {
                    viewModel.confirmCompletion()
                }
                Button("Na", role: .cancel) {
                    viewModel.cancelConfirmation()
                }
            } message: {
                Text("Ba taeed, in parking memory az in iPhone pak mishe.")
            }
            .sheet(isPresented: detailsEditorBinding) {
                if let detailsDraft {
                    ParkingDetailsEditor(
                        initialDraft: detailsDraft,
                        onCancel: {
                            self.detailsDraft = nil
                            viewModel.cancelDetailsEditing()
                        },
                        onSave: { updatedDraft in
                            viewModel.saveDetails(updatedDraft)
                            self.detailsDraft = nil
                        }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        ZStack {
            LinearGradient(colors: [Color.accentColor.opacity(0.16), Color(uiColor: .systemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image("ParkingExample")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .accessibilityLabel("Sample photo of a parked car beside a colored parking column")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Yadet bemone koja parke")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Ye aks az ja begir, ya tabaghe o neshone ro ezafe kon.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }
        }
        .safeAreaInset(edge: .bottom) {
            parkingActionBar {
                Button {
                    viewModel.tapPark()
                } label: {
                    Label("Park kardam", systemImage: "car.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .accessibilityHint("Jaye park ro save mikone.")
            }
        }
    }

    private var activeState: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                if let memory = viewModel.activeMemory {
                    VStack(alignment: .leading, spacing: 20) {
                        activeHero(memory)
                            .modifier(ParkingPhotoActions(
                                isShowingChoices: $isShowingPhotoChoices,
                                memoryID: memory.id,
                                hasPhoto: memory.parkingPhotoData != nil,
                                onSave: { data, memoryID in
                                    viewModel.savePhoto(data, for: memoryID)
                                }
                            ))
                        parkingDetails(memory)
                        locationStatus
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 112)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            parkingActionBar {
                NavigationLink {
                    FindMyCarView(viewModel: viewModel)
                } label: {
                    Label("Mashinam ro peyda kon", systemImage: "location.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .accessibilityHint("Aks, detail o location-e save shode ro neshon mide.")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Mashin ro peyda kardam", systemImage: "checkmark.circle", role: .destructive) {
                        viewModel.requestCompletion()
                    }

                    Button("Park-e jadid save kon", systemImage: "arrow.triangle.2.circlepath", role: .destructive) {
                        viewModel.tapPark()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Kare digar-e park")
                .accessibilityHint("Gozinehaye tamoom kardan ya avaz kardan-e park ro neshon mide.")
            }
        }
    }

    private func activeHero(_ memory: ParkingMemory) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            parkingStatusHeader(memory)

            Text("Mashinet injast")
                .font(.system(.title, design: .rounded, weight: .bold))

            if memory.parkingPhotoData != nil {
                parkingPhoto(memory)
            } else {
                addPhotoButton
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.green.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }

    @ViewBuilder
    private func parkingStatusHeader(_ memory: ParkingMemory) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                Label("Park shode", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(elapsedParkingTime(from: memory.parkedAt, to: context.date))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            HStack {
                Label("Park shode", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Spacer()
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(elapsedParkingTime(from: memory.parkedAt, to: context.date))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func parkingPhoto(_ memory: ParkingMemory) -> some View {
        if let photoData = memory.parkingPhotoData,
           let image = UIImage(data: photoData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityLabel("Aks-e park")
                .overlay(alignment: .topTrailing) {
                    Button {
                        isShowingPhotoChoices = true
                    } label: {
                        Image(systemName: "pencil")
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Aks ro edit kon")
                    .padding(10)
                }
        }
    }

    private var addPhotoButton: some View {
        Button {
            isShowingPhotoChoices = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.title2)
                Text("Aks ezafe kon")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 132)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .accessibilityHint("Doorbin ya Photos ro baz mikone.")
    }

    @ViewBuilder
    private func parkingDetails(_ memory: ParkingMemory) -> some View {
        if memory.hasTextDetails {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Detail")
                        .font(.title2.weight(.semibold))

                    Spacer()

                    Button("Edit") {
                        openDetailsEditor()
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    parkingDetailRow("Tabaghe", value: memory.floor, systemImage: "square.stack.3d.up")
                    parkingDetailRow("Bakhsh", value: memory.section, systemImage: "rectangle.split.3x1")
                    parkingDetailRow("Ja ya sotoon", value: memory.spot, systemImage: "number")
                    parkingDetailRow("Neshone", value: memory.landmark, systemImage: "mappin.and.ellipse")
                    parkingDetailRow("Yaddasht", value: memory.note, systemImage: "note.text")
                }
            }
            .parkingSectionStyle()
            .accessibilityElement(children: .contain)
        } else {
            Button("Detail ezafe kon", systemImage: "plus") {
                openDetailsEditor()
            }
            .font(.headline)
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private var locationStatus: some View {
        switch viewModel.locationCaptureState {
        case .idle:
            EmptyView()
        case .capturing:
            HStack(spacing: 8) {
                ProgressView()
                Text("Dar hale gereftane location…")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
        case let .saved(horizontalAccuracy):
            locationSummaryRow(horizontalAccuracy)
        case .unavailable:
            VStack(alignment: .leading, spacing: 12) {
                Label("Location save nashod", systemImage: "location.slash")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("Park bedoon location save shode.")
                    .foregroundStyle(.secondary)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { locationRecoveryActions }
                    VStack(alignment: .leading, spacing: 8) { locationRecoveryActions }
                }
            }
            .parkingSectionStyle()
            .accessibilityElement(children: .contain)
        case .manual:
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Label("Bedoon location", systemImage: "mappin.slash")
                    Spacer()
                    addLocationButton
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label("Bedoon location", systemImage: "mappin.slash")
                    addLocationButton
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
        }
    }

    private func locationSummaryRow(_ horizontalAccuracy: Double) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                Label("Location-e taghribi", systemImage: "location.fill")
                Spacer()
                Text(locationAccuracyDescription(horizontalAccuracy))
            }
            VStack(alignment: .leading, spacing: 4) {
                Label("Location-e taghribi", systemImage: "location.fill")
                Text(locationAccuracyDescription(horizontalAccuracy))
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    private var addLocationButton: some View {
        Button("Ezafe kon") {
            viewModel.retryLocationCapture()
        }
        .buttonStyle(.plain)
        .fontWeight(.medium)
        .frame(minHeight: 44)
        .foregroundStyle(.tint)
        .accessibilityLabel("Location ezafe kon")
    }

    @ViewBuilder
    private var locationRecoveryActions: some View {
        Button("Dobare talash kon", systemImage: "arrow.clockwise") {
            viewModel.retryLocationCapture()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

        Button("Bedoon location negah dar") {
            viewModel.keepManualParkingMemory()
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func locationAccuracyDescription(_ horizontalAccuracy: Double) -> String {
        let roundedAccuracy = Int(horizontalAccuracy.rounded(.up))
        return "~\(roundedAccuracy) m"
    }

    private func elapsedParkingTime(from parkedAt: Date, to now: Date) -> String {
        let elapsedSeconds = max(0, now.timeIntervalSince(parkedAt))

        if elapsedSeconds < 60 {
            return "Alan"
        }

        let elapsedMinutes = Int(elapsedSeconds / 60)
        if elapsedMinutes < 60 {
            return "\(elapsedMinutes) min"
        }

        let elapsedHours = elapsedMinutes / 60
        if elapsedHours < 24 {
            return "\(elapsedHours) hr"
        }

        return "\(elapsedHours / 24) rooz"
    }

    private func openDetailsEditor() {
        detailsDraft = viewModel.beginEditingDetails()
    }

    @ViewBuilder
    private func parkingDetailRow(_ label: String, value: String?, systemImage: String) -> some View {
        if let value {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.body)
                }
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }
        }
    }

    private var persistenceFailureState: some View {
        ContentUnavailableView {
            Label("Save nashod", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Park ro natoonestim az in iPhone bekhoonim ya save konim.")
        }
        .safeAreaInset(edge: .bottom) {
            parkingActionBar {
                Button {
                    viewModel.restore()
                } label: {
                    Label("Dobare talash kon", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
        }
    }

    private func parkingActionBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.ultraThinMaterial)
    }

    private func alertBinding(for screen: ParkingViewModel.Screen) -> Binding<Bool> {
        Binding(
            get: { viewModel.screen == screen },
            set: { isPresented in
                if !isPresented { viewModel.cancelConfirmation() }
            }
        )
    }

    private var detailsEditorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.screen == .editing },
            set: { isPresented in
                if !isPresented, viewModel.screen == .editing {
                    detailsDraft = nil
                    viewModel.cancelDetailsEditing()
                }
            }
        )
    }
}

private extension ParkingMemory {
    var hasTextDetails: Bool {
        floor != nil || section != nil || spot != nil || landmark != nil || note != nil
    }
}

private extension View {
    func parkingSectionStyle() -> some View {
        padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ParkingMemory.self, inMemory: true)
}
