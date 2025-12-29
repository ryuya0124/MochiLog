import SwiftUI

struct StatisticsView: View {
  let filteredRecords: [BatteryRecord]

  private var averageHealth: Double {
    guard !filteredRecords.isEmpty else { return 0 }
    let total = filteredRecords.reduce(0) { sum, record in
      sum
        + (appSettings.analysisDataSource == .nominal
          ? record.nominalHealthPercent : record.healthPercent)
    }
    return total / Double(filteredRecords.count)
  }

  @StateObject private var appSettings = AppSettings.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(String(localized: "statistics", table: "Analytics"))
        .font(.headline)

      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        StatCard(
          title: String(localized: "record_count", table: "Analytics"),
          value: "\(filteredRecords.count)",
          icon: "doc.text.fill",
          color: .blue
        )

        StatCard(
          title: String(
            localized: appSettings.analysisDataSource == .nominal
              ? "stat_average_nominal" : "stat_average_actual",
            table: "Analytics"),
          value: String(format: "%.1f%%", averageHealth),
          icon: "heart.fill",
          color: healthColor(averageHealth)
        )

        if let latest = filteredRecords.last {
          StatCard(
            title: String(localized: "cycle_count", table: "Analytics"),
            value: "\(latest.cycleCount)",
            icon: "arrow.triangle.2.circlepath",
            color: .purple
          )

          StatCard(
            title: String(
              localized: appSettings.analysisDataSource == .nominal
                ? "stat_latest_nominal" : "stat_latest_actual",
              table: "Analytics"),
            value: String(
              format: "%.1f%%",
              appSettings.analysisDataSource == .nominal
                ? latest.nominalHealthPercent : latest.healthPercent),
            icon: "battery.100",
            color: healthColor(
              appSettings.analysisDataSource == .nominal
                ? latest.nominalHealthPercent : latest.healthPercent)
          )
        }
      }
    }
    .padding()
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }

  private func healthColor(_ percent: Double) -> Color {
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return appSettings.accentColor.color
  }
}

// MARK: - 統計カード
struct StatCard: View {
  let title: String
  let value: String
  let icon: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: icon)
          .foregroundStyle(color)
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Text(value)
        .font(.title2)
        .fontWeight(.bold)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
  }
}

#Preview {
  StatisticsView(filteredRecords: [])
}
