//
//  FindMyCarView.swift
//  Parked
//

import SwiftUI
import UIKit

struct FindMyCarView: View {
    @Bindable var viewModel: ParkingViewModel

    var body: some View {
        Group {
            if let memory = viewModel.activeMemory {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        recallCues(for: memory)

                        if let location = memory.locationEstimate {
                            returnContext(location: location)
                        } else {
                            manualMemoryMessage
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            } else {
                ContentUnavailableView {
                    Label("Parki nadari", systemImage: "car")
                } description: {
                    Text("Baraye peyda kardan-e mashin, aval ye park save kon.")
                }
            }
        }
        .navigationTitle("Peyda kardan-e mashin")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.beginFindMyCar()
        }
        .onDisappear {
            viewModel.endFindMyCar()
        }
    }

    private func recallCues(for memory: ParkingMemory) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mashinet injast")
                .font(.title2.weight(.bold))

            if let photoData = memory.parkingPhotoData,
               let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityLabel("Aks-e park")
            }

            if memory.hasRecallDetails {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Joz'iyat-e park")
                        .font(.headline)
                    detailRows(for: memory)
                }
            } else if memory.parkingPhotoData == nil {
                Text("Az joz'iyat ya aks-e park baraye yadet oomadan estefade kon.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .findSectionStyle()
    }

    @ViewBuilder
    private func detailRows(for memory: ParkingMemory) -> some View {
        detailRow("Tabaghe", value: memory.floor, systemImage: "square.stack.3d.up")
        detailRow("Bakhsh", value: memory.section, systemImage: "rectangle.split.3x1")
        detailRow("Ja ya sotoon", value: memory.spot, systemImage: "number")
        detailRow("Neshone", value: memory.landmark, systemImage: "mappin.and.ellipse")
        detailRow("Yaddasht", value: memory.note, systemImage: "note.text")
    }

    @ViewBuilder
    private func detailRow(_ label: String, value: String?, systemImage: String) -> some View {
        if let value {
            Label {
                LabeledContent(label, value: value)
                    .font(.body)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }
        }
    }

    @ViewBuilder
    private func returnContext(location: ParkingLocationEstimate) -> some View {
        returnDistance
        savedLocationMap(location)

        if let directionsURL = viewModel.directionsURL {
            Link(destination: directionsURL) {
                Label("Ba Maps rahnemayi begir", systemImage: "arrow.triangle.turn.up.right.diamond")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("Apple Maps ro baraye masir baz mikone.")
        }
    }

    @ViewBuilder
    private var returnDistance: some View {
        switch viewModel.findMyCarLocationState {
        case .available:
            if let distance = viewModel.returnDistanceDescription {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Fasele ta mashin", systemImage: "figure.walk")
                        .font(.headline)
                    Text(distance)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Fasele mostaghim, na masir-e ranandegi")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .findSectionStyle()
                .accessibilityElement(children: .combine)
            }
        case .capturing:
            HStack(spacing: 10) {
                ProgressView()
                Text("Dar hale gereftane location-e alan…")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        case .unavailable:
            VStack(alignment: .leading, spacing: 6) {
                Label("Fasele maloom nist", systemImage: "location.slash")
                    .font(.headline)
                Text("Location-e alan dastres nist. Aks, joz'iyat o location-e save shode hamechenan injan.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .findSectionStyle()
        case .idle, .recallCuesOnly:
            EmptyView()
        }
    }

    private func savedLocationMap(_ location: ParkingLocationEstimate) -> some View {
        Group {
            if viewModel.mapAvailabilityState == .available {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Location-e save shode")
                        .font(.headline)
                    SavedParkingMapView(location: location) {
                        viewModel.mapDidFailToLoad()
                    }
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(mapAccessibilityLabel(for: location))

                    Label(
                        "Location taghribi ta had-e \(Int(location.horizontalAccuracy.rounded(.up))) metr",
                        systemImage: "scope"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Map dastres nist", systemImage: "map.fill")
                        .font(.headline)
                    Text("Connection ro check kon. Aks, joz'iyat o location-e save shode hamechenan injan.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .findSectionStyle()
            }
        }
    }

    private var manualMemoryMessage: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Location save nashod", systemImage: "mappin.slash")
                .font(.headline)
            Text("Baraye peyda kardan-e mashin, az aks o joz'iyat-e park estefade kon.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .findSectionStyle()
    }

    private func mapAccessibilityLabel(for location: ParkingLocationEstimate) -> String {
        "Map-e jaye park. Daghati ta had-e \(Int(location.horizontalAccuracy.rounded(.up))) metr."
    }
}

private extension ParkingMemory {
    var hasRecallDetails: Bool {
        floor != nil || section != nil || spot != nil || landmark != nil || note != nil
    }
}

private extension View {
    func findSectionStyle() -> some View {
        padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
    }
}
