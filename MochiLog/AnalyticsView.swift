import Charts
import SwiftData
import SwiftUI

// MARK: - 分析ビュー
struct AnalyticsView: View {
  @Query(sort: \BatteryRecord.logDate, order: .forward) private var records: [BatteryRecord]
  @State private var selectedDevice: String?

  private var deviceNames: [String] {
    Array(Set(records.map { $0.deviceName })).sorted()
  }

  private var filteredRecords: [BatteryRecord] {
    guard let device = selectedDevice else { return records }
    return records.filter { $0.deviceName == device }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          if records.isEmpty {
            ContentUnavailableView(
              String(localized: "no_data"),
              systemImage: "chart.line.uptrend.xyaxis",
              description: Text(String(localized: "no_data_description"))
            )
            .frame(maxHeight: .infinity)
          } else {
            // デバイス選択ピッカー
            devicePickerSection

            // ヘルス推移グラフ
            healthTrendSection

            // サイクル推移グラフ
            cycleTrendSection

            // 統計情報
            if !filteredRecords.isEmpty {
              statisticsSection
            }
          }
        }
        .padding()
      }
      .navigationTitle(String(localized: "analytics"))
      .background(Color(.systemGroupedBackground))
    }
  }

  // MARK: - デバイス選択
  private var devicePickerSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(String(localized: "select_a_device"))
        .font(.headline)
        .foregroundStyle(.secondary)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          // 全デバイス
          DeviceChip(
            name: String(localized: "all_devices"),
            isSelected: selectedDevice == nil
          ) {
            selectedDevice = nil
          }

          ForEach(deviceNames, id: \.self) { device in
            DeviceChip(
              name: device,
              isSelected: selectedDevice == device
            ) {
              selectedDevice = device
            }
          }
        }
      }
    }
  }

  // MARK: - ヘルス推移グラフ
  private var healthTrendSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(String(localized: "health_trend"))
        .font(.headline)

      if filteredRecords.isEmpty {
        Text(String(localized: "no_records_for_device"))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding()
      } else {
        Chart {
          ForEach(filteredRecords) { record in
            LineMark(
              x: .value(String(localized: "date"), record.logDate),
              y: .value(String(localized: "real_capacity"), record.healthPercent)
            )
            .foregroundStyle(by: .value(String(localized: "device_name"), record.deviceName))
            .symbol(by: .value(String(localized: "device_name"), record.deviceName))

            PointMark(
              x: .value(String(localized: "date"), record.logDate),
              y: .value(String(localized: "real_capacity"), record.healthPercent)
            )
            .foregroundStyle(by: .value(String(localized: "device_name"), record.deviceName))
          }

          // 80%ラインを表示
          RuleMark(y: .value("Threshold", 80))
            .foregroundStyle(.red.opacity(0.5))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            .annotation(position: .trailing, alignment: .leading) {
              Text("80%")
                .font(.caption2)
                .foregroundStyle(.red)
            }
        }
        .chartYScale(domain: 70...105)
        .chartYAxis {
          AxisMarks(values: [70, 80, 90, 100]) { value in
            AxisGridLine()
            AxisValueLabel {
              if let intValue = value.as(Int.self) {
                Text("\(intValue)%")
              }
            }
          }
        }
        .frame(height: 220)
      }
    }
    .padding()
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }

  // MARK: - サイクル推移グラフ
  private var cycleTrendSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(String(localized: "cycle_trend"))
        .font(.headline)

      if filteredRecords.isEmpty {
        Text(String(localized: "no_records_for_device"))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding()
      } else {
        Chart {
          ForEach(filteredRecords) { record in
            BarMark(
              x: .value(String(localized: "date"), record.logDate),
              y: .value(String(localized: "cycle_count"), record.cycleCount)
            )
            .foregroundStyle(by: .value(String(localized: "device_name"), record.deviceName))
          }
        }
        .frame(height: 180)
      }
    }
    .padding()
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }

  // MARK: - 統計情報
  private var statisticsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(String(localized: "statistics"))
        .font(.headline)

      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        StatCard(
          title: String(localized: "record_count"),
          value: "\(filteredRecords.count)",
          icon: "doc.text.fill",
          color: .blue
        )

        StatCard(
          title: String(localized: "average_health"),
          value: String(format: "%.1f%%", averageHealth),
          icon: "heart.fill",
          color: healthColor(averageHealth)
        )

        if let latest = filteredRecords.last {
          StatCard(
            title: String(localized: "latest_cycle"),
            value: "\(latest.cycleCount)",
            icon: "arrow.triangle.2.circlepath",
            color: .purple
          )

          StatCard(
            title: String(localized: "latest_health"),
            value: String(format: "%.1f%%", latest.healthPercent),
            icon: "battery.100",
            color: healthColor(latest.healthPercent)
          )
        }
      }
    }
    .padding()
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }

  private var averageHealth: Double {
    guard !filteredRecords.isEmpty else { return 0 }
    let total = filteredRecords.reduce(0) { $0 + $1.healthPercent }
    return total / Double(filteredRecords.count)
  }

  private func healthColor(_ percent: Double) -> Color {
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return .green
  }
}

// MARK: - デバイスチップ
struct DeviceChip: View {
  let name: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(name)
        .font(.subheadline)
        .fontWeight(isSelected ? .semibold : .regular)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
          isSelected
            ? Color.green.opacity(0.2)
            : Color(.systemGray5)
        )
        .foregroundStyle(isSelected ? .green : .primary)
        .clipShape(Capsule())
        .overlay(
          Capsule()
            .stroke(isSelected ? Color.green : Color.clear, lineWidth: 1.5)
        )
    }
    .buttonStyle(.plain)
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
  AnalyticsView()
    .modelContainer(for: BatteryRecord.self, inMemory: true)
}
