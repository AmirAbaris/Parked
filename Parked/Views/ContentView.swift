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
            let viewModel = ParkingViewModel(modelContext: modelContext)
            viewModel.restore()
            parkingViewModel = viewModel
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
            .alert("In park delete beshe?", isPresented: alertBinding(for: .completionConfirmation)) {
                Button("Delete", role: .destructive) {
                    viewModel.confirmCompletion()
                }
                Button("Na", role: .cancel) {
                    viewModel.cancelConfirmation()
                }
            } message: {
                Text("Aks o joz'iyat-e in park az in iPhone pak mishe.")
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "parkingsign.circle.fill")
                    .font(.system(size: 64))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Jaye mashineto save kon")
                        .font(.largeTitle.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Ba ye tap save kon. Aks o joz'iyat ro ba'dan ezafe kon.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
            .padding(.horizontal, 24)
            .padding(.bottom, 112)
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
        ScrollView {
            if let memory = viewModel.activeMemory {
                VStack(alignment: .leading, spacing: 24) {
                    parkingPhoto(memory)
                    parkingTime(memory.parkedAt)
                    parkingDetails(memory)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 112)
            }
        }
        .safeAreaInset(edge: .bottom) {
            parkingActionBar {
                GlassEffectContainer(spacing: 12) {
                    activeActionLayout {
                        Button {
                            viewModel.tapPark()
                        } label: {
                            Label("Dobare park kardam", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .accessibilityHint("Ba taeed, park-e ghabli ro avaz mikone.")

                        Button(role: .destructive) {
                            viewModel.requestCompletion()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.glass)
                        .tint(.red)
                        .accessibilityHint("Ba taeed, in park o joz'iyatesh ro pak mikone.")
                    }
                }
            }
        }
    }

    private var activeActionLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(spacing: 12))
        } else {
            AnyLayout(HStackLayout(spacing: 12))
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
        }
    }

    private func parkingTime(_ parkedAt: Date) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Label("Park shod", systemImage: "clock")
                .font(.headline)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(parkedAt, style: .relative)
                    .font(.headline)

                Text(parkedAt, format: .dateTime.weekday(.abbreviated).hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Divider()
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
        .accessibilityElement(children: .contain)
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

#Preview {
    ContentView()
        .modelContainer(for: ParkingMemory.self, inMemory: true)
}
