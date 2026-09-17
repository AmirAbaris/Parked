//
//  ContentView.swift
//  Parked
//
//  Created by Amir Abaris on 9/16/26.
//

import SwiftData
import SwiftUI

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

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.screen {
                case .empty:
                    emptyState
                case .saving:
                    ProgressView("Darim yadet ro save mikonim…")
                case .active, .replacementConfirmation, .completionConfirmation:
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
}

#Preview {
    ContentView()
        .modelContainer(for: ParkingMemory.self, inMemory: true)
}
