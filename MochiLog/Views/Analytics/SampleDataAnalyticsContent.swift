import SwiftUI

// MARK: - サンプルデータ分析ビュー
/// データがない時にサンプルデータでグラフを表示するビュー
/// 共通のグラフ表示コンポーネントを使用してコード重複を排除
@MainActor
struct SampleDataAnalyticsContent: View {
  @Binding var showingSampleData: Bool
  @Binding var selectedRange: RangePreset
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @State private var selectedDevice: String?
  @State private var windowEnd: Date = Date()
  @State private var hasInitialized = false

  private let sampleRecords = SampleDataProvider.generateSampleRecords()

  private var deviceNames: [String] {
    SampleDataProvider.sampleDeviceNames
  }

  private var filteredRecords: [BatteryRecord] {
    guard let device = selectedDevice else { return sampleRecords }
    return sampleRecords.filter { $0.deviceName == device }
  }

  /// 全デバイス名（ソート済み）— チャートの色安定割り当て用
  private var sortedAllDeviceNames: [String] {
    SampleDataProvider.sampleDeviceNames.sorted()
  }

  // MARK: - 共通ユーティリティを使用したプロパティ

  private var canMoveNext: Bool {
    ChartWindowNavigator.canMoveNext(
      currentEnd: windowEnd, range: selectedRange, records: filteredRecords)
  }

  private var canMovePrevious: Bool {
    ChartWindowNavigator.canMovePrevious(
      currentEnd: windowEnd, range: selectedRange, records: filteredRecords)
  }

  private func shiftWindow(backward: Bool) {
    windowEnd = ChartWindowNavigator.shiftWindow(
      currentEnd: windowEnd,
      backward: backward,
      range: selectedRange,
      records: filteredRecords
    )
  }

  var body: some View {
    let _ = print("[Performance] SampleDataAnalyticsContent.body構築開始")
    let bodyStartTime = CFAbsoluteTimeGetCurrent()

    return VStack(spacing: 20) {
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

      // 期間計算（共通ロジック）
      let dates = filteredRecords.map { $0.logDate }
      let window = computeWindow(recordDates: dates, windowEnd: windowEnd, range: selectedRange)

      let calendar = Calendar.current
      let startDay = window.startDay
      let endDay = window.endDay

      let visibleRecords = filteredRecords.filter {
        let d = calendar.startOfDay(for: $0.logDate)
        return d >= startDay && d <= endDay
      }

      // チャート用：ウィンドウ外の前後コンテキストレコードを含む（補間線描画用）
      let chartRecords = ChartWindowNavigator.visibleRecordsWithContext(
        in: filteredRecords,
        start: startDay,
        end: endDay
      )

      let unit = window.unit

      let _ = {
        let elapsed = (CFAbsoluteTimeGetCurrent() - bodyStartTime) * 1000
        print(
          "[Performance] SampleDataAnalyticsContent.body計算完了: \(String(format: "%.2f", elapsed))ms")
      }()

      // iPad: 2列レイアウト、iPhone: 1列レイアウト
      if horizontalSizeClass == .regular {
        // iPad向け2列グリッド
        VStack(spacing: 20) {
          HStack(alignment: .top, spacing: 20) {
            // ヘルス推移グラフ
            HealthTrendView(
              visibleRecords: chartRecords,
              startDay: startDay,
              endDay: endDay,
              unit: unit,
              selectedRange: $selectedRange,
              canMoveNext: canMoveNext,
              canMovePrevious: canMovePrevious,
              shiftWindow: shiftWindow,
              allDeviceNames: sortedAllDeviceNames
            )

            // サイクル推移グラフ（iPadは独立動作、initialRangeで初期化）
            CycleTrendView(
              allRecords: filteredRecords,
              unit: unit,
              initialRange: selectedRange
            )
          }

          // 統計情報（iPad）
          StatisticsView(filteredRecords: visibleRecords)
        }
        .frame(maxWidth: 1200)
      } else {
        // iPhone向け1列レイアウト
        // ヘルス推移グラフ
        HealthTrendView(
          visibleRecords: chartRecords,
          startDay: startDay,
          endDay: endDay,
          unit: unit,
          selectedRange: $selectedRange,
          canMoveNext: canMoveNext,
          canMovePrevious: canMovePrevious,
          shiftWindow: shiftWindow,
          allDeviceNames: sortedAllDeviceNames
        )

        // サイクル推移グラフ（iPhoneでは親と期間を共有）
        CycleTrendView(
          allRecords: filteredRecords,
          unit: unit,
          initialRange: selectedRange,
          sharedSelectedRange: $selectedRange,
          sharedWindowEnd: $windowEnd,
          sharedCanMoveNext: canMoveNext,
          sharedCanMovePrevious: canMovePrevious,
          sharedShiftWindow: shiftWindow,
          sharedWindowEndValue: windowEnd
        )

        // 統計情報（iPhone）
        StatisticsView(filteredRecords: visibleRecords)
      }
    }
    .padding(.horizontal)
    .onAppear {
      guard !hasInitialized else { return }
      hasInitialized = true

      // ウィンドウ終了日を初期化
      windowEnd = ChartWindowNavigator.initializeWindowEnd(
        for: filteredRecords, range: selectedRange)
      // 自動でレンジを設定
      let autoRange = ChartWindowNavigator.autoRange(for: filteredRecords)
      if selectedRange != autoRange {
        selectedRange = autoRange
      }
    }
    .onChange(of: selectedRange) { _, newValue in
      windowEnd = ChartWindowNavigator.adjustedWindowEndForRangeChange(
        range: newValue,
        currentEnd: windowEnd,
        records: filteredRecords
      )
    }
  }

  private func computeWindow(
    recordDates: [Date],
    windowEnd: Date,
    range: RangePreset
  ) -> (startDay: Date, endDay: Date, unit: AppSettings.ChartUnit) {
    let calendar = Calendar.current
    let effectiveRange = computeEffectiveRange(for: recordDates, range: range)
    let effectiveEnd = computeEffectiveEnd(
      for: recordDates,
      windowEnd: windowEnd,
      range: range
    )

    let startDate = computeWindowStart(for: effectiveEnd, range: effectiveRange)
    let startDay = calendar.startOfDay(for: startDate)
    let endDay = calendar.startOfDay(for: effectiveEnd)

    let visibleDates = recordDates.filter {
      let d = calendar.startOfDay(for: $0)
      return d >= startDay && d <= endDay
    }

    let unit = computeAutoUnit(for: visibleDates, startDay: startDay, endDay: endDay)

    return (startDay, endDay, unit)
  }

  private func computeEffectiveRange(for recordDates: [Date], range: RangePreset) -> RangePreset {
    guard range == .auto else { return range }
    let now = Date()
    let pastDates = recordDates.filter { $0 <= now }
    let sourceDates = pastDates.isEmpty ? recordDates : pastDates
    guard let first = sourceDates.min(), let last = sourceDates.max() else { return .oneMonth }
    let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0

    if days <= 7 { return .oneWeek }
    if days <= 14 { return .twoWeeks }
    if days <= 30 { return .oneMonth }
    if days <= 90 { return .threeMonths }
    if days <= 180 { return .sixMonths }
    if days <= 365 { return .oneYear }
    if days <= 730 { return .twoYears }
    return .threeYears
  }

  private func computeEffectiveEnd(
    for recordDates: [Date],
    windowEnd: Date,
    range: RangePreset
  ) -> Date {
    guard range == .auto else { return windowEnd }
    let now = Date()
    if windowEnd <= now { return windowEnd }
    let pastDates = recordDates.filter { $0 <= now }
    if let latestPast = pastDates.max() { return latestPast }
    return min(windowEnd, now)
  }

  private func computeWindowStart(for endDate: Date, range: RangePreset) -> Date {
    let calendar = Calendar.current
    switch range {
    case .auto:
      return endDate
    case .oneWeek:
      return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
    case .twoWeeks:
      return calendar.date(byAdding: .day, value: -14, to: endDate) ?? endDate
    case .oneMonth:
      let components = calendar.dateComponents([.year, .month], from: endDate)
      return calendar.date(from: components) ?? endDate
    case .threeMonths:
      let month = calendar.component(.month, from: endDate)
      let year = calendar.component(.year, from: endDate)
      let quarterStartMonth = ((month - 1) / 3) * 3 + 1
      var components = DateComponents()
      components.year = year
      components.month = quarterStartMonth
      components.day = 1
      return calendar.date(from: components) ?? endDate
    case .sixMonths:
      let month = calendar.component(.month, from: endDate)
      let year = calendar.component(.year, from: endDate)
      var components = DateComponents()
      components.year = year
      components.month = month <= 6 ? 1 : 7
      components.day = 1
      return calendar.date(from: components) ?? endDate
    case .oneYear:
      let components = calendar.dateComponents([.year], from: endDate)
      return calendar.date(from: components) ?? endDate
    case .twoYears:
      let year = calendar.component(.year, from: endDate)
      var components = DateComponents()
      components.year = year - 1
      components.month = 1
      components.day = 1
      return calendar.date(from: components) ?? endDate
    case .threeYears:
      let year = calendar.component(.year, from: endDate)
      var components = DateComponents()
      components.year = year - 2
      components.month = 1
      components.day = 1
      return calendar.date(from: components) ?? endDate
    }
  }

  private func computeAutoUnit(
    for dates: [Date],
    startDay: Date,
    endDay: Date
  ) -> AppSettings.ChartUnit {
    let calendar = Calendar.current
    let days = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    let count = dates.count

    if days <= 2 && count > 24 { return .hour }
    if days <= 14 { return .day }
    if days <= 120 { return .day }
    if days <= 730 { return .week }
    return .month
  }
}

#Preview {
  SampleDataAnalyticsContent(
    showingSampleData: .constant(true),
    selectedRange: .constant(.threeYears)
  )
}
