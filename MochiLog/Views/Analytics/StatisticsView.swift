import SwiftUI

struct StatisticsView: View {
  let filteredRecords: [BatteryRecord]
  private let recordsByDevice: [String: [BatteryRecord]]

  init(filteredRecords: [BatteryRecord]) {
    self.filteredRecords = filteredRecords
    self.recordsByDevice = Dictionary(grouping: filteredRecords, by: \.deviceName)
  }
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @ObservedObject private var appSettings = AppSettings.shared

  private var deviceNames: [String] {
    let names = Set(recordsByDevice.keys)
    var remaining = names
    let preferred = appSettings.deviceSortOrder.filter { remaining.remove($0) != nil }
    return preferred + remaining.sorted()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 5) {
        Label(L10n.string("statistics", table: "Analytics"), systemImage: "chart.bar.xaxis")
          .font(.headline)
        Text(L10n.string("statistics_scope", table: "Analytics"))
          .font(.caption).foregroundStyle(.secondary)
      }

      if filteredRecords.isEmpty {
        Text(L10n.string("statistics_empty", table: "Analytics"))
          .font(.subheadline).foregroundStyle(.secondary)
          .padding(.vertical, 16)
      } else {
        LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize
          ? [GridItem(.flexible())]
          : [GridItem(.adaptive(minimum: 280), spacing: 16)], alignment: .leading, spacing: 16) {
          ForEach(deviceNames, id: \.self) { name in
            deviceStatistics(name)
          }
        }
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .mochiCard()
    .accessibilityIdentifier("analytics.statistics")
  }

  @ViewBuilder
  private func deviceStatistics(_ name: String) -> some View {
    let records = (recordsByDevice[name] ?? [])
    let latest = records.max {
      if $0.logDate != $1.logDate { return $0.logDate < $1.logDate }
      if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
      return $0.id.uuidString < $1.id.uuidString
    }
    if let latest {
      let values = records.map { health($0) }.filter { $0.isFinite }
      let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 5) {
          Text(name).font(.headline)
          Text(latest.logDate, style: .date)
            .font(.caption).foregroundStyle(.secondary)
        }
        VStack(alignment: .leading, spacing: 6) {
          Text(L10n.string(appSettings.analysisDataSource == .nominal
            ? "stat_latest_nominal" : "stat_latest_actual", table: "Analytics"))
            .font(.caption).foregroundStyle(.secondary)
          Text(percent(health(latest)))
            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(healthColor(health(latest)))
        }
        Divider()
        let layout = dynamicTypeSize.isAccessibilitySize
          ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
          : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
          metric(L10n.string("record_count", table: "Analytics"), value: records.count.formatted(), icon: "doc.text")
          metric(L10n.string("cycle_count", table: "Analytics"), value: latest.cycleCount.formatted(), icon: "arrow.triangle.2.circlepath")
        }
        metric(L10n.string(appSettings.analysisDataSource == .nominal
          ? "stat_average_nominal" : "stat_average_actual", table: "Analytics"),
          value: average.map(percent) ?? "—", icon: "chart.bar")
      }
      .padding(20)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(Color(uiColor: .tertiarySystemGroupedBackground),
        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("statistics.device.\(name)")
    }
  }

  private func health(_ record: BatteryRecord) -> Double {
    appSettings.analysisDataSource == .nominal ? record.nominalHealthPercent : record.healthPercent
  }

  private func percent(_ value: Double) -> String {
    guard value.isFinite else { return "—" }
    return (value / 100).formatted(.percent.precision(.fractionLength(1)))
  }

  private func metric(_ title: String, value: String, icon: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
      Text(value).font(.system(.title3, design: .rounded, weight: .medium)).monospacedDigit()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func healthColor(_ percent: Double) -> Color {
    if !percent.isFinite { return .secondary }
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return appSettings.accentColor.color
  }
}

#Preview {
  StatisticsView(filteredRecords: [])
}
