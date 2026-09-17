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
    @Bindable var viewModel: ParkingViewModel
    @State private var detailsDraft: ParkingDetailsDraft?

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.screen {
                case .empty:
                    emptyState
                case .saving:
                    ProgressView("Darim yadet ro save mikonim…")
                case .active, .editing, .replacementConfirmation, .completionConfirmation:
                    activeState
                case .persistenceFailure:
                    persistenceFailureState
                }
            }
            .navigationTitle("Parked")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if viewModel.activeMemory != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.requestCompletion()
                        } label: {
                            Label("Mashineto peyda kardi?", systemImage: "checkmark")
                        }
                        .accessibilityHint("Yade park ro ba taeed pak mikone.")
                    }
                }
            }
            .alert("Yade park ghabli avaz beshe?", isPresented: alertBinding(for: .replacementConfirmation)) {
                Button("Avaz kon", role: .destructive) {
                    viewModel.confirmReplacement()
                }
                Button("Kheyr", role: .cancel) {
                    viewModel.cancelConfirmation()
                }
            } message: {
                Text("Yade ghabli pak mishe va yade jadid save mishe.")
            }
            .alert("Mashineto peyda kardi?", isPresented: alertBinding(for: .completionConfirmation)) {
                Button("Bale, tamoom shod", role: .destructive) {
                    viewModel.confirmCompletion()
                }
                Button("Hanooz na", role: .cancel) {
                    viewModel.cancelConfirmation()
                }
            } message: {
                Text("Yade park az ruye in iPhone pak mishe.")
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
                    Text("Parket ro yadet negah dar")
                        .font(.largeTitle.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Ba ye tap, ye yade park save kon ta vaghti bargashti, mashineto rahat-tar peyda koni.")
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
                    Label("Mashinamo park kardam", systemImage: "car.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .accessibilityHint("Yek yade park jadid save mikone.")
            }
        }
    }

    private var activeState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Yade parket save shode", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)

                    Text("Yade parket save shode.")
                        .font(.largeTitle.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Vaghti bargashti, yadet mimune.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                if let parkedAt = viewModel.activeMemory?.parkedAt {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Vaght-e park", systemImage: "clock")
                            .font(.headline)

                        Text(parkedAt, format: .dateTime.weekday(.wide).hour().minute())
                            .font(.title3.weight(.semibold))

                        Text(parkedAt, style: .relative)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .top) {
                        Divider()
                    }
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
                }

                if let memory = viewModel.activeMemory {
                    parkingDetails(memory)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 112)
        }
        .safeAreaInset(edge: .bottom) {
            parkingActionBar {
                Button {
                    viewModel.tapPark()
                } label: {
                    Label("Dobare park kardam", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .accessibilityHint("Ba taeed, yade park ghabli ro avaz mikone.")
            }
        }
    }

    private func parkingDetails(_ memory: ParkingMemory) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Joz'iyat-e park")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button(memory.hasParkingDetails ? "Virayesh" : "Ezafe kon") {
                    detailsDraft = viewModel.beginEditingDetails()
                }
            }

            if let photoData = memory.parkingPhotoData,
               let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityLabel("Aks-e park")
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
                Text("Tabaghe, bakhsh, ja, neshone ya aks ro faghat vaghti lazem dari ezafe kon.")
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
            Text("Yade park ro natoonestim az in iPhone bekhoonim ya save konim.")
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
