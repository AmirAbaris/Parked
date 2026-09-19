import SwiftUI
import UIKit
import WidgetKit

struct ParkedWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ParkingWidgetStore.kind, provider: ParkingWidgetTimelineProvider()) { entry in
            ParkedWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(uiColor: .systemBackground)
                }
        }
        .configurationDisplayName("Parked")
        .description("Aks o detail-e parking ro neshon mide.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct ParkingWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: ParkingWidgetSnapshot?
}

struct ParkingWidgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ParkingWidgetEntry {
        ParkingWidgetEntry(date: .now, snapshot: previewSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (ParkingWidgetEntry) -> Void) {
        completion(ParkingWidgetEntry(date: .now, snapshot: ParkingWidgetStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ParkingWidgetEntry>) -> Void) {
        let entry = ParkingWidgetEntry(date: .now, snapshot: ParkingWidgetStore.read())
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private var previewSnapshot: ParkingWidgetSnapshot {
        ParkingWidgetSnapshotBuilder.make(
            parkingID: UUID(),
            parkedAt: .now.addingTimeInterval(-4_800),
            floor: "B2",
            section: "Abi",
            spot: "C-14",
            hasParkingPhoto: false
        )
    }
}

private struct ParkedWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ParkingWidgetEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                activeParking(snapshot)
            } else {
                emptyParking
            }
        }
        .widgetURL(entry.snapshot == nil ? ParkingWidgetRoute.appURL : ParkingWidgetRoute.findMyCarURL)
    }

    @ViewBuilder
    private func activeParking(_ snapshot: ParkingWidgetSnapshot) -> some View {
        switch family {
        case .systemSmall:
            smallActiveParking(snapshot)
        default:
            mediumActiveParking(snapshot)
        }
    }

    private func smallActiveParking(_ snapshot: ParkingWidgetSnapshot) -> some View {
        ZStack(alignment: .bottomLeading) {
            parkingImage(for: snapshot)

            LinearGradient(
                colors: [.clear, .black.opacity(0.74)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(locationSummary(for: snapshot))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(elapsedParkingTime(from: snapshot.parkedAt, to: entry.date))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: snapshot))
    }

    private func mediumActiveParking(_ snapshot: ParkingWidgetSnapshot) -> some View {
        ZStack(alignment: .bottomLeading) {
            parkingImage(for: snapshot)

            LinearGradient(
                colors: [.clear, .black.opacity(0.76)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 5) {
                Label("Park shode", systemImage: "car.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)

                Text(locationSummary(for: snapshot))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(elapsedParkingTime(from: snapshot.parkedAt, to: entry.date))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.86))
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: snapshot))
    }

    @ViewBuilder
    private func parkingImage(for snapshot: ParkingWidgetSnapshot) -> some View {
        if let data = ParkingWidgetStore.photoData(named: snapshot.photoFilename),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            photoNeededParking
        }
    }

    private var photoNeededParking: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer()
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.tint)
            Text("Aks ezafe kon")
                .font(.headline)
            Text("Widget aks-e park ro neshon mide.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
        .background {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.18), Color(uiColor: .secondarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var emptyParking: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "car.side.and.exclamationmark")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.tint)
            Spacer()
            Text("Parki nadari")
                .font(.headline)
            Text("Baraye save kardan, Parked ro baz kon.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Parki nadari. Baraye save kardan, Parked ro baz kon.")
    }

    private func locationSummary(for snapshot: ParkingWidgetSnapshot) -> String {
        let details = [snapshot.floor, snapshot.section, snapshot.spot].compactMap { $0 }
        return details.isEmpty ? "Jaye park" : details.joined(separator: " · ")
    }

    private func elapsedParkingTime(from parkedAt: Date, to now: Date) -> String {
        let elapsedSeconds = max(0, now.timeIntervalSince(parkedAt))
        if elapsedSeconds < 60 { return "Alan" }

        let minutes = Int(elapsedSeconds / 60)
        if minutes < 60 { return "\(minutes) min" }

        let hours = minutes / 60
        if hours < 24 { return "\(hours) hr" }
        return "\(hours / 24) rooz"
    }

    private func accessibilityLabel(for snapshot: ParkingWidgetSnapshot) -> String {
        let details = [snapshot.floor, snapshot.section, snapshot.spot]
            .compactMap { $0 }
            .joined(separator: ", ")
        let elapsedTime = elapsedParkingTime(from: snapshot.parkedAt, to: entry.date)
        return details.isEmpty ? "Park shode. \(elapsedTime)" : "Park shode. \(details). \(elapsedTime)"
    }
}

#Preview(as: .systemMedium) {
    ParkedWidget()
} timeline: {
    ParkingWidgetEntry(
        date: .now,
        snapshot: ParkingWidgetSnapshotBuilder.make(
            parkingID: UUID(),
            parkedAt: .now.addingTimeInterval(-7_200),
            floor: "B2",
            section: "Abi",
            spot: "C-14",
            hasParkingPhoto: false
        )
    )
}
