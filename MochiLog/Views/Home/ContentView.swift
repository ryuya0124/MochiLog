import SwiftUI

struct ContentView: View {
  var body: some View {
    MainTabView()
  }
}


/// Shared surfaces keep charts, summaries and settings visually consistent.
struct MochiCardSurface: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content
      .background(Color(uiColor: .secondarySystemGroupedBackground),
        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.045), lineWidth: 1)
      }
      .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.025), radius: 12, y: 5)
  }
}

extension View {
  func mochiCard() -> some View { modifier(MochiCardSurface()) }
}

struct LibrarySummaryView: View {
  let records: [BatteryRecord]
  @ObservedObject private var settings = AppSettings.shared
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  private var deviceNames: [String] {
    let names = Set(records.map(\.deviceName))
    let preferred = settings.deviceSortOrder.filter { names.contains($0) }
    return preferred + names.subtracting(preferred).sorted()
  }

  var body: some View {
    LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize
      ? [GridItem(.flexible())]
      : [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
      ForEach(deviceNames, id: \.self) { name in
        let deviceRecords = records.filter { $0.deviceName == name }
        if let latest = deviceRecords.max(by: {
          if $0.logDate != $1.logDate { return $0.logDate < $1.logDate }
          if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
          return $0.id.uuidString < $1.id.uuidString
        }) {
          summary(latest, recordCount: deviceRecords.count)
        }
      }
    }
    .accessibilityIdentifier("home.librarySummary")
  }

  @ViewBuilder
  private func summary(_ latest: BatteryRecord, recordCount: Int) -> some View {
      let health = settings.analysisDataSource == .nominal
        ? latest.nominalHealthPercent : latest.healthPercent
      VStack(alignment: .leading, spacing: 20) {
        Label(L10n.string("battery_health", table: "Records"), systemImage: "battery.100")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)

        ViewThatFits(in: .horizontal) {
          HStack(alignment: .center, spacing: 24) {
            reading(health: health)
            Spacer(minLength: 8)
            device(latest)
          }
          VStack(alignment: .leading, spacing: 12) {
            reading(health: health)
            device(latest)
          }
        }

        Divider()
        let layout = dynamicTypeSize.isAccessibilitySize
          ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
          : AnyLayout(HStackLayout(alignment: .top, spacing: 24))
        layout {
          metric(L10n.string("record_count", table: "Analytics"), value: recordCount,
            icon: "doc.text")
          metric(L10n.string("cycle_count", table: "Analytics"), value: latest.cycleCount,
            icon: "arrow.triangle.2.circlepath")
        }
      }
      .padding(24)
      .mochiCard()
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("home.deviceSummary.\(latest.deviceName)")
  }

  private func reading(health: Double) -> some View {
    Text(health / 100, format: .percent.precision(.fractionLength(1)))
      .font(.system(.largeTitle, design: .rounded, weight: .semibold))
      .monospacedDigit()
      .foregroundStyle(health < 80 ? Color.red : health < 90 ? Color.orange : settings.accentColor.color)
      .fixedSize(horizontal: true, vertical: false)
  }

  private func device(_ record: BatteryRecord) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(record.deviceName).font(.headline)
      Text(record.logDate, style: .date).font(.subheadline).foregroundStyle(.secondary)
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  private func metric(_ title: String, value: Int, icon: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
      Text(value, format: .number)
        .font(.system(.title3, design: .rounded, weight: .semibold))
        .monospacedDigit()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
