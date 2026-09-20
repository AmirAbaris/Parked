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
            photoData: nil
        )
    }
}

private struct ParkedWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
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
        if hasDisplayableParkingPhoto(snapshot) {
            switch family {
            case .systemSmall:
                smallActiveParking(snapshot)
            default:
                mediumActiveParking(snapshot)
            }
        } else {
            photoRequiredParking
        }
    }

    private func smallActiveParking(_ snapshot: ParkingWidgetSnapshot) -> some View {
        ZStack(alignment: .bottom) {
            parkingImage(for: snapshot)

            LinearGradient(
                colors: [.clear, .black.opacity(0.62)],
                startPoint: .center,
                endPoint: .bottom
            )

            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "mappin.circle.fill")
                    Text(smallLocationCue(for: snapshot))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(.black.opacity(0.38), in: Capsule())

                Spacer(minLength: 0)
            }
            .padding(10)
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
        if let data = snapshot.photoData,
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            EmptyView()
        }
    }

    private var photoRequiredParking: some View {
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

    private func hasDisplayableParkingPhoto(_ snapshot: ParkingWidgetSnapshot) -> Bool {
        guard let data = snapshot.photoData else { return false }
        return UIImage(data: data) != nil
    }

    private var emptyParking: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: emptyBackgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "parkingsign.circle.fill")
                .font(.system(size: family == .systemSmall ? 74 : 104, weight: .medium))
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.10) : .blue.opacity(0.14))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(family == .systemSmall ? 12 : 18)

            VStack(alignment: .leading, spacing: 5) {
                Label("Parked", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                Text("Har vaght park kardi,\nyadam mimune.")
                    .font(family == .systemSmall ? .subheadline.weight(.semibold) : .title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text("Aks o detail-e jaye park injast.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(family == .systemSmall ? 13 : 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Parked. Har vaght park kardi, yadam mimune.")
    }

    private var emptyBackgroundColors: [Color] {
        colorScheme == .dark
            ? [Color(red: 0.08, green: 0.14, blue: 0.22), Color(red: 0.17, green: 0.12, blue: 0.16)]
            : [Color(red: 0.90, green: 0.95, blue: 1), Color(red: 0.98, green: 0.94, blue: 0.88)]
    }

    private func locationSummary(for snapshot: ParkingWidgetSnapshot) -> String {
        let details = [snapshot.floor, snapshot.section, snapshot.spot].compactMap { $0 }
        return details.isEmpty ? "Jaye park" : details.joined(separator: " · ")
    }

    private func smallLocationCue(for snapshot: ParkingWidgetSnapshot) -> String {
        snapshot.spot ?? snapshot.floor ?? snapshot.section ?? "Jaye park"
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
            photoData: nil
        )
    )
}
