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
                locationProvider: CoreLocationParkingLocationProvider()
            )
            viewModel.restore()
            parkingViewModel = viewModel
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                parkingViewModel?.stopLocationCaptureForBackground()
            }
        }
    }
}

private struct ParkingHomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var viewModel: ParkingViewModel
    @State private var detailsDraft: ParkingDetailsDraft?

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
                Text("Aks o joz'iyat-e park-e ghabli pak mishe.")
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
                VStack(spacing: 4) {
                    Button {
                        viewModel.requestCompletion()
                    } label: {
                        Label("Peydash kardam", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityHint("Baraye pak kardane in parking memory taeed migire.")

                    Button("Dobare park kardam", systemImage: "arrow.triangle.2.circlepath") {
                        viewModel.tapPark()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityHint("Ba taeed, park-e ghabli ro avaz mikone.")
                }
            }
        }
    }

    private func activeHero(_ memory: ParkingMemory) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Park shode", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Spacer()
                Text(memory.parkedAt, style: .relative)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if memory.parkingPhotoData != nil { parkingPhoto(memory) }

            VStack(alignment: .leading, spacing: 6) {
                Text("Mashinet injast")
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text("Joz'iyate zir komaket mikone peydash koni.")
                    .foregroundStyle(.secondary)
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
    private func parkingPhoto(_ memory: ParkingMemory) -> some View {
        if let photoData = memory.parkingPhotoData,
           let image = UIImage(data: photoData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityLabel("Aks-e park")
        }
    }

    private func parkingTime(_ parkedAt: Date) -> some View {
        parkingTimeLayout {
            Label("Park shod", systemImage: "clock")
                .font(.headline)

            VStack(alignment: .trailing, spacing: 2) {
                Text(parkedAt, style: .relative)
                    .font(.headline)

                Text(parkedAt, format: .dateTime.weekday(.abbreviated).hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(
                maxWidth: .infinity,
                alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing
            )
        }
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var parkingTimeLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        } else {
            AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        }
    }

    private func parkingDetails(_ memory: ParkingMemory) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Joz'iyat")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button(memory.hasParkingDetails ? "Edit" : "Ezafe kon") {
                    detailsDraft = viewModel.beginEditingDetails()
                }
            }

            if memory.hasTextDetails {
                VStack(alignment: .leading, spacing: 14) {
                    parkingDetailRow("Tabaghe", value: memory.floor, systemImage: "square.stack.3d.up")
                    parkingDetailRow("Bakhsh", value: memory.section, systemImage: "rectangle.split.3x1")
                    parkingDetailRow("Ja ya sotoon", value: memory.spot, systemImage: "number")
                    parkingDetailRow("Neshone", value: memory.landmark, systemImage: "mappin.and.ellipse")
                    parkingDetailRow("Yaddasht", value: memory.note, systemImage: "note.text")
                }
            } else if memory.parkingPhotoData == nil {
                Text("Aks, tabaghe ya neshone ezafe kon.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .parkingSectionStyle()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var locationStatus: some View {
        switch viewModel.locationCaptureState {
        case .idle:
            EmptyView()
        case .capturing:
            locationStatusCard(
                status: "Dar hale gereftan",
                systemImage: "location"
            ) {
                HStack(alignment: .top, spacing: 10) {
                    ProgressView()
                    Text("Park save shode. Darim location-e taghribi ro ham ezafe mikonim…")
                }
            }
        case let .saved(horizontalAccuracy):
            locationStatusCard(
                status: "Save shode",
                systemImage: "location.fill",
                statusColor: .green
            ) {
                Text(locationAccuracyDescription(horizontalAccuracy))
                    .font(.body.weight(.medium))
                Text("In noghte taghribiye. Too parking-e sarpooshide momkene deghatesh kamtar bashe.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .unavailable:
            locationStatusCard(
                status: "Save nashod",
                systemImage: "location.slash",
                statusColor: .orange
            ) {
                Text("Park bedoon location save shode. Aks o joz'iyat-et hamchenan hast.")
                    .foregroundStyle(.secondary)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { locationRecoveryActions }
                    VStack(alignment: .leading, spacing: 8) { locationRecoveryActions }
                }
            }
        case .manual:
            locationStatusCard(
                status: "Ezafe nashode",
                systemImage: "mappin.slash"
            ) {
                Text("In park bedoon location save shode. Mitoni har vaght khasti ezafash koni.")
                    .foregroundStyle(.secondary)
                Button("Location ezafe kon", systemImage: "location") {
                    viewModel.retryLocationCapture()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private func locationStatusCard<Content: View>(
        status: String,
        systemImage: String,
        statusColor: Color = .secondary,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            locationHeaderLayout {
                Label("Location-e park", systemImage: systemImage)
                    .font(.headline)

                Text(status)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .frame(maxWidth: .infinity, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
            }

            content()
        }
        .parkingSectionStyle()
        .accessibilityElement(children: .contain)
    }

    private var locationHeaderLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
        } else {
            AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        }
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
        return "Location ta hodood \(roundedAccuracy) metre deghat dare."
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

    var hasParkingDetails: Bool {
        hasTextDetails || parkingPhotoData != nil
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
