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
    @State private var parkingState: ParkingStateModel?

    var body: some View {
        Group {
            if let parkingState {
                ParkingHomeView(parkingState: parkingState)
            } else {
                ProgressView()
            }
        }
        .task {
            guard parkingState == nil else { return }
            let state = ParkingStateModel(modelContext: modelContext)
            state.restore()
            parkingState = state
        }
    }
}

private struct ParkingHomeView: View {
    @Bindable var parkingState: ParkingStateModel

    var body: some View {
        NavigationStack {
            Group {
                switch parkingState.screen {
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
                if parkingState.activeMemory != nil {
                    Button("Mashineto peyda kardi?") {
                        parkingState.requestCompletion()
                    }
                }
            }
            .alert("Yade park ghabli avaz beshe?", isPresented: alertBinding(for: .replacementConfirmation)) {
                Button("Avaz kon", role: .destructive) {
                    parkingState.confirmReplacement()
                }
                Button("Kheyr", role: .cancel) {
                    parkingState.cancelConfirmation()
                }
            } message: {
                Text("Yade ghabli pak mishe va yade jadid save mishe.")
            }
            .alert("Mashineto peyda kardi?", isPresented: alertBinding(for: .completionConfirmation)) {
                Button("Bale, tamoom shod", role: .destructive) {
                    parkingState.confirmCompletion()
                }
                Button("Hanooz na", role: .cancel) {
                    parkingState.cancelConfirmation()
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
                parkingState.tapPark()
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
                if let parkedAt = parkingState.activeMemory?.parkedAt {
                    Text(parkedAt, style: .relative)
                        .foregroundStyle(.secondary)
                    Text(parkedAt, style: .time)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Dobare park kardam") {
                parkingState.tapPark()
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
                parkingState.restore()
            }
            .buttonStyle(.bordered)
        }
    }

    private func alertBinding(for screen: ParkingStateModel.Screen) -> Binding<Bool> {
        Binding(
            get: { parkingState.screen == screen },
            set: { isPresented in
                if !isPresented { parkingState.cancelConfirmation() }
            }
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ParkingMemory.self, inMemory: true)
}
