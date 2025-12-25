import Charts
import SwiftData
import SwiftUI

// MARK: - 分析ビュー
struct AnalyticsView: View {
  @Query(sort: \BatteryRecord.logDate, order: .forward) private var records: [BatteryRecord]
  @State private var selectedDevice: String?
  @StateObject private var appSettings = AppSettings.shared

  // チャート単位/範囲用
  enum RangePreset: String, CaseIterable, Identifiable {
    case oneWeek = "1w"
    case oneMonth = "1m"
    case threeMonths = "3m"
    case all = "all"

    var id: String { self.rawValue }

    /// ローカライズされた表示名
    var localizedName: String {
      switch self {
      case .oneWeek:
        return String(localized: "range_1w")
      case .oneMonth:
        return String(localized: "range_1m")
      case .threeMonths:
        return String(localized: "range_3m")
      case .all:
        return String(localized: "range_all")
      }
    }
  }

  @State private var selectedRange: RangePreset = .oneMonth

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var animateChart: Bool = false

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
        // チャートコントロール：単位と範囲
        if horizontalSizeClass == .compact {
          VStack(spacing: 8) {
            Picker(String(localized: "chart_unit_day"), selection: $appSettings.defaultChartUnit) {
              ForEach(AppSettings.ChartUnit.allCases) { unit in
                Text(unit.localizedName).tag(unit)
              }
            }
            .pickerStyle(.menu)

            Picker(String(localized: "chart_range"), selection: $selectedRange) {
              ForEach(RangePreset.allCases) { preset in
                Text(preset.localizedName).tag(preset)
              }
            }
            .pickerStyle(.menu)
          }
        } else {
          HStack(spacing: 12) {
            Picker(String(localized: "chart_unit_day"), selection: $appSettings.defaultChartUnit) {
              ForEach(AppSettings.ChartUnit.allCases) { unit in
                Text(unit.localizedName).tag(unit)
              }
            }
            .pickerStyle(.segmented)

            Picker(String(localized: "chart_range"), selection: $selectedRange) {
              ForEach(RangePreset.allCases) { preset in
                Text(preset.localizedName).tag(preset)
              }
            }
            .pickerStyle(.segmented)
          }
        }

        let endDate = Date()
        let calendar = Calendar.current
        let startDate: Date = {
          switch selectedRange {
          case .oneWeek:
            return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
          case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
          case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
          case .all:
            return (filteredRecords.min(by: { $0.logDate < $1.logDate })?.logDate) ?? endDate
          }
        }()

        let visibleRecords = filteredRecords.filter {
          $0.logDate >= startDate && $0.logDate <= endDate
        }

        Chart {
          ForEach(visibleRecords) { record in
            LineMark(
              x: .value(
                String(localized: "date"), record.logDate,
                unit: appSettings.defaultChartUnit.calendarComponent),
              y: .value(String(localized: "real_capacity"), record.healthPercent)
            )
            .foregroundStyle(by: .value(String(localized: "device_name"), record.deviceName))
            .symbol(by: .value(String(localized: "device_name"), record.deviceName))
            .interpolationMethod(.catmullRom)
            .opacity(animateChart ? 1 : 0)

            PointMark(
              x: .value(
                String(localized: "date"), record.logDate,
                unit: appSettings.defaultChartUnit.calendarComponent),
              y: .value(String(localized: "real_capacity"), record.healthPercent)
            )
            .foregroundStyle(by: .value(String(localized: "device_name"), record.deviceName))
            .scaleEffect(y: animateChart ? 1 : 0, anchor: .bottom)
            .opacity(animateChart ? 1 : 0)
            .animation(.easeOut(duration: 0.6), value: animateChart)
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
        .chartXAxis {
          // 範囲を明示的に指定
          AxisMarks(values: .automatic(desiredCount: 5))
        }
        .chartXScale(domain: startDate...endDate)
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
        // プロットエリアだけをマスクして、軸を静的に保つ（データだけ下から伸びる）
        .chartPlotStyle { plotArea in
          plotArea
            .mask {
              GeometryReader { geo in
                Rectangle()
                  .frame(height: animateChart ? geo.size.height : 0, alignment: .bottom)
                  .frame(maxHeight: .infinity, alignment: .bottom)
                  .animation(.easeOut(duration: 0.6), value: animateChart)
              }
            }
        }
        .frame(height: 220)
        // 伸びるアニメーション（下から上にスケール）

        .onAppear {
          // 初回フェードインと伸びるアニメーション
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.6)) { animateChart = true }
          }
        }
        .onChange(of: selectedRange) {
          // 範囲が変わったら一旦リセットして再アニメーション（軸はアニメーションしない）
          animateChart = false
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withAnimation(.easeOut(duration: 0.5)) { animateChart = true }
          }
        }
        .onChange(of: appSettings.defaultChartUnit) {
          // 単位が変わったらデータ部のみ再アニメーション
          animateChart = false
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withAnimation(.easeOut(duration: 0.45)) { animateChart = true }
          }
        }
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
        // 同じ範囲フィルタを再利用
        let endDate = Date()
        let calendar = Calendar.current
        let startDate: Date = {
          switch selectedRange {
          case .oneWeek:
            return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
          case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
          case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
          case .all:
            return (filteredRecords.min(by: { $0.logDate < $1.logDate })?.logDate) ?? endDate
          }
        }()

        let visibleRecords = filteredRecords.filter {
          $0.logDate >= startDate && $0.logDate <= endDate
        }

        Chart {
          ForEach(visibleRecords) { record in
            LineMark(
              x: .value(
                String(localized: "date"), record.logDate,
                unit: appSettings.defaultChartUnit.calendarComponent),
              y: .value(String(localized: "cycle_count"), record.cycleCount)
            )
            .foregroundStyle(by: .value(String(localized: "device_name"), record.deviceName))
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            // データ部分のみ下から伸びるアニメーション
            .scaleEffect(y: animateChart ? 1 : 0, anchor: .bottom)
            .opacity(animateChart ? 1 : 0)
            .animation(.easeOut(duration: 0.6), value: animateChart)

            PointMark(
              x: .value(
                String(localized: "date"), record.logDate,
                unit: appSettings.defaultChartUnit.calendarComponent),
              y: .value(String(localized: "cycle_count"), record.cycleCount)
            )
            .foregroundStyle(by: .value(String(localized: "device_name"), record.deviceName))
            .symbolSize(40)
            .opacity(animateChart ? 1 : 0)
          }
        }
        .chartXScale(domain: startDate...Date())
        // プロットエリアだけをマスクしてデータ部のみアニメーション（軸は動かさない）
        .chartPlotStyle { plotArea in
          plotArea
            .mask {
              GeometryReader { geo in
                Rectangle()
                  .frame(height: animateChart ? geo.size.height : 0, alignment: .bottom)
                  .frame(maxHeight: .infinity, alignment: .bottom)
                  .animation(.easeOut(duration: 0.6), value: animateChart)
              }
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
