import SwiftUI

// MARK: - サンプルデータ分析ビュー
/// データがない時にサンプルデータでグラフを表示するビュー
/// 共通のグラフ表示コンポーネントを使用してコード重複を排除
struct SampleDataAnalyticsContent: View {
  @Binding var showingSampleData: Bool
  @Binding var animateChart: Bool
  @Binding var selectedRange: RangePreset
  @StateObject private var appSettings = AppSettings.shared

  @State private var selectedDevice: String?
  @State private var windowEnd: Date = Date()

  private let sampleRecords = SampleDataProvider.generateSampleRecords()

  private var deviceNames: [String] {
    SampleDataProvider.sampleDeviceNames
  }

  private var filteredRecords: [BatteryRecord] {
    guard let device = selectedDevice else { return sampleRecords }
    return sampleRecords.filter { $0.deviceName == device }
  }

  var body: some View {
    VStack(spacing: 20) {
      // サンプルデータバナー
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

      // 期間計算
      let calendar = Calendar.current
      let startDate = windowStart(for: windowEnd, range: selectedRange, allRecords: filteredRecords)
      let startDay = calendar.startOfDay(for: startDate)
      let endDay = calendar.startOfDay(for: windowEnd)

      let visibleRecords = filteredRecords.filter {
        let d = calendar.startOfDay(for: $0.logDate)
        return d >= startDay && d <= endDay
      }

      let unit = autoUnit(for: visibleRecords, startDay: startDay, endDay: endDay)

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
      // ウィンドウ終了日を初期化
      initializeWindowEnd()
      // 自動でレンジを設定
      selectedRange = autoRange(for: filteredRecords)

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        withAnimation(.easeOut(duration: 0.6)) {
          animateChart = true
        }
      }
    }
  }

  // MARK: - ヘルパー関数

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
      return calendar.date(byAdding: .month, value: -24, to: endDate) ?? endDate
    case .all:
      return allRecords.min(by: { $0.logDate < $1.logDate })?.logDate ?? endDate
    }
  }

  private func autoUnit(for records: [BatteryRecord], startDay: Date, endDay: Date)
    -> AppSettings.ChartUnit
  {
    let calendar = Calendar.current
    let days = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    let count = records.count

    if days <= 2 && count > 24 { return .hour }
    if days <= 14 { return .day }
    if days <= 120 { return .week }
    return .month
  }

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

  private func initializeWindowEnd() {
    if let last = filteredRecords.max(by: { $0.logDate < $1.logDate })?.logDate {
      windowEnd = last
    } else {
      windowEnd = Date()
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
