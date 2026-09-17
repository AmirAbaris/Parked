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
            .toolbar {
                if viewModel.activeMemory != nil {
                    Button("Mashineto peyda kardi?") {
                    viewModel.requestCompletion()
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
        ContentUnavailableView {
            Label("Yade park nadari", systemImage: "car")
        } description: {
            Text("Alan mashineto park kardi? Ba ye tap jash ro save kon.")
        } actions: {
            Button("Mashinamo park kardam") {
                viewModel.tapPark()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Yek yade park jadid save mikone.")
        }
    }

    private var activeState: some View {
        VStack(spacing: 24) {
            Image(systemName: "car.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Yade parket save shode")
                    .font(.title2.weight(.semibold))
                if let parkedAt = viewModel.activeMemory?.parkedAt {
                    Text(parkedAt, style: .relative)
                        .foregroundStyle(.secondary)
                    Text(parkedAt, style: .time)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Dobare park kardam") {
                viewModel.tapPark()
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Ba taeed, yade park ghabli ro avaz mikone.")
        }
        .multilineTextAlignment(.center)
        .padding()
    }

    private var persistenceFailureState: some View {
        ContentUnavailableView {
            Label("Save nashod", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Yade park ro natoonestim az in iPhone bekhoonim ya save konim.")
        } actions: {
            Button("Dobare talash kon") {
                viewModel.restore()
            }
            .buttonStyle(.bordered)
        }
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
