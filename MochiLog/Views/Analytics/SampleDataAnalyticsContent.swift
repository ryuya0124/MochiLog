import SwiftUI

// MARK: - サンプルデータ分析ビュー
/// データがない時にサンプルデータでグラフを表示するビュー
struct SampleDataAnalyticsContent: View {
  @Binding var showingSampleData: Bool
  @Binding var animateChart: Bool
  @Binding var selectedRange: RangePreset
  @StateObject private var appSettings = AppSettings.shared

  @State private var selectedDevice: String?

  private let sampleRecords = SampleDataProvider.generateSampleRecords()

  private var deviceNames: [String] {
    SampleDataProvider.sampleDeviceNames
  }

  private var filteredRecords: [BatteryRecord] {
    guard let device = selectedDevice else { return sampleRecords }
    return sampleRecords.filter { $0.deviceName == device }
  }

  /// データ期間に基づいて最適なレンジを決定
  private func autoRange(for records: [BatteryRecord]) -> RangePreset {
    guard let first = records.min(by: { $0.logDate < $1.logDate })?.logDate,
      let last = records.max(by: { $0.logDate < $1.logDate })?.logDate
    else { return .all }

    let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0

    if days <= 7 { return .oneWeek }
    if days <= 30 { return .oneMonth }
    if days <= 90 { return .threeMonths }
    if days <= 180 { return .sixMonths }
    if days <= 365 { return .oneYear }
    if days <= 730 { return .twoYears }
    return .all
  }

  // MARK: - ウィンドウ（前後移動）ヘルパー (AnalyticsViewと同じロジック)
  private func periodComponent(for preset: RangePreset) -> DateComponents? {
    switch preset {
    case .oneWeek: return DateComponents(day: 7)
    case .oneMonth: return DateComponents(month: 1)
    case .threeMonths: return DateComponents(month: 3)
    case .sixMonths: return DateComponents(month: 6)
    case .oneYear: return DateComponents(year: 1)
    case .twoYears: return DateComponents(year: 2)
    case .all: return nil
    }
  }

  private func windowStart(for endDate: Date, range: RangePreset, allRecords: [BatteryRecord])
    -> Date
  {
    let calendar = Calendar.current
    switch range {
    case .oneWeek:
      return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
    case .oneMonth:
      return calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
    case .threeMonths:
      return calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
    case .sixMonths:
      return calendar.date(byAdding: .month, value: -6, to: endDate) ?? endDate
    case .oneYear:
      return calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
    case .twoYears:
      return calendar.date(byAdding: .year, value: -2, to: endDate) ?? endDate
    case .all:
      return allRecords.min(by: { $0.logDate < $1.logDate })?.logDate ?? endDate
    }
  }

  var body: some View {
    VStack(spacing: 20) {
      // サンプルデータバナー（スクロールと一緒に動く）
      SampleDataBanner(
        onClose: {
          withAnimation {
            showingSampleData = false
          }
        },
        onAddData: {}
      )

      // デバイス選択ピッカー
      DevicePickerView(deviceNames: deviceNames, selectedDevice: $selectedDevice)

      // フィルタリング計算
      // 常に最新データを基準にする（サンプルデータなのでリアルタイム更新などはない前提）
      // windowEnd は全期間の最後とする
      let allFiltered = filteredRecords
      let windowEnd = allFiltered.max(by: { $0.logDate < $1.logDate })?.logDate ?? Date()
      let calendar = Calendar.current

      let startDate: Date = {
        if selectedRange == .all {
          return allFiltered.min(by: { $0.logDate < $1.logDate })?.logDate ?? windowEnd
        } else {
          return windowStart(for: windowEnd, range: selectedRange, allRecords: allFiltered)
        }
      }()

      let startDay = calendar.startOfDay(for: startDate)
      let endDay = calendar.startOfDay(for: windowEnd)

      let visibleRecords = allFiltered.filter {
        let d = calendar.startOfDay(for: $0.logDate)
        return d >= startDay && d <= endDay
      }

      // 自動でunit決定
      // 表示中の期間(days)に基づいて決定する
      let days = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
      let unit: AppSettings.ChartUnit = {
        if days <= 2 && visibleRecords.count > 24 { return .hour }
        if days <= 14 { return .day }
        if days <= 120 { return .week }
        return .month
      }()

      // ヘルス推移グラフ
      HealthTrendView(
        visibleRecords: visibleRecords,
        startDay: startDay,
        endDay: endDay,
        unit: unit,
        selectedRange: $selectedRange,
        canMoveNext: false,
        canMovePrevious: false,
        shiftWindow: { _ in },
        animateChart: $animateChart
      )

      // サイクル推移グラフ
      CycleTrendView(
        visibleRecords: visibleRecords,
        startDay: startDay,
        endDay: endDay,
        unit: unit,
        animateChart: $animateChart
      )

      // 統計情報
      StatisticsView(filteredRecords: visibleRecords)
    }
    .padding(.horizontal)
    .onAppear {
      // 初期表示時は自動でレンジを設定
      selectedRange = autoRange(for: filteredRecords)

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        withAnimation(.easeOut(duration: 0.6)) {
          animateChart = true
        }
      }
    }
  }
}

#Preview {
  SampleDataAnalyticsContent(
    showingSampleData: .constant(true),
    animateChart: .constant(true),
    selectedRange: .constant(.all)
  )
}
