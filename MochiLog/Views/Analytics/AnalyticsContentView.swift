import SwiftUI

/// 分析画面のコンテンツビュー（バックグラウンドでデータ準備）
/// AnalyticsViewから使用される実データ表示用のコンポーネント
@MainActor
struct AnalyticsContentView: View {
  let records: [BatteryRecord]
  @Binding var selectedDevice: String?
  let cachedDeviceNames: [String]
  @Binding var selectedRange: RangePreset
  @Binding var windowEnd: Date

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  // MARK: - バックグラウンド計算用の状態
  @State private var isLoading = true
  @State private var cachedFilteredRecords: [BatteryRecord] = []
  @State private var cachedVisibleRecords: [BatteryRecord] = []
  @State private var cachedStartDay: Date = Date()
  @State private var cachedEndDay: Date = Date()
  @State private var cachedUnit: AppSettings.ChartUnit = .day
  @State private var lastQuickSignature: Int?
  @State private var lastParametersHash: Int?

  // MARK: - フィルタ済みレコード
  private var filteredRecords: [BatteryRecord] {
    cachedFilteredRecords
  }

  // MARK: - ナビゲーション
  private var effectiveRangeForNavigation: RangePreset {
    if selectedRange != .auto { return selectedRange }
    let now = Date()
    let pastRecords = filteredRecords.filter { $0.logDate <= now }
    let sourceRecords = pastRecords.isEmpty ? filteredRecords : pastRecords
    return ChartWindowNavigator.autoRange(for: sourceRecords)
  }

  private var effectiveWindowEndForNavigation: Date {
    if selectedRange != .auto { return windowEnd }
    let now = Date()
    if windowEnd <= now { return windowEnd }
    let pastRecords = filteredRecords.filter { $0.logDate <= now }
    if let latestPast = pastRecords.max(by: { $0.logDate < $1.logDate })?.logDate {
      return latestPast
    }
    return min(windowEnd, now)
  }

  private var canMoveNext: Bool {
    ChartWindowNavigator.canMoveNext(
      currentEnd: effectiveWindowEndForNavigation,
      range: effectiveRangeForNavigation,
      records: filteredRecords)
  }

  private var canMovePrevious: Bool {
    ChartWindowNavigator.canMovePrevious(
      currentEnd: effectiveWindowEndForNavigation,
      range: effectiveRangeForNavigation,
      records: filteredRecords)
  }

  private func shiftWindow(backward: Bool) {
    windowEnd = ChartWindowNavigator.shiftWindow(
      currentEnd: effectiveWindowEndForNavigation,
      backward: backward,
      range: effectiveRangeForNavigation,
      records: filteredRecords
    )
  }

  var body: some View {
    ZStack {
      if isLoading && cachedVisibleRecords.isEmpty {
        // 初回ローディング中
        VStack(spacing: 16) {
          ProgressView()
            .scaleEffect(1.2)
          Text(String(localized: "preparing_data", table: "Home"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        // コンテンツ表示
        ScrollView {
          VStack(spacing: 20) {
            // デバイス選択ピッカー（スクロールと一緒に動く）
            DevicePickerView(deviceNames: cachedDeviceNames, selectedDevice: $selectedDevice)

            // iPad: 2列レイアウト、iPhone: 1列レイアウト
            if horizontalSizeClass == .regular {
              // iPad向け：グラフと統計を同じ幅にまとめる
              VStack(spacing: 20) {
                // iPad向け2列グリッド
                HStack(alignment: .top, spacing: 20) {
                  // ヘルス推移グラフ
                  HealthTrendView(
                    visibleRecords: cachedVisibleRecords,
                    startDay: cachedStartDay,
                    endDay: cachedEndDay,
                    unit: cachedUnit,
                    selectedRange: $selectedRange,
                    canMoveNext: canMoveNext,
                    canMovePrevious: canMovePrevious,
                    shiftWindow: shiftWindow
                  )

                  // サイクル推移グラフ
                  CycleTrendView(
                    allRecords: cachedFilteredRecords,
                    unit: cachedUnit,
                    initialRange: selectedRange
                  )
                }

                // 統計情報（iPad）
                if !cachedFilteredRecords.isEmpty {
                  StatisticsView(filteredRecords: cachedFilteredRecords)
                }
              }
              .frame(maxWidth: 1200)
            } else {
              // iPhone向け1列レイアウト
              // ヘルス推移グラフ
              HealthTrendView(
                visibleRecords: cachedVisibleRecords,
                startDay: cachedStartDay,
                endDay: cachedEndDay,
                unit: cachedUnit,
                selectedRange: $selectedRange,
                canMoveNext: canMoveNext,
                canMovePrevious: canMovePrevious,
                shiftWindow: shiftWindow
              )

              // サイクル推移グラフ（iPhoneでは親と期間を共有）
              CycleTrendView(
                allRecords: cachedFilteredRecords,
                unit: cachedUnit,
                initialRange: selectedRange,
                sharedSelectedRange: $selectedRange,
                sharedWindowEnd: $windowEnd,
                sharedCanMoveNext: canMoveNext,
                sharedCanMovePrevious: canMovePrevious,
                sharedShiftWindow: shiftWindow
              )

              // 統計情報（iPhone）
              if !cachedFilteredRecords.isEmpty {
                StatisticsView(filteredRecords: cachedFilteredRecords)
              }
            }
          }
          .padding()
        }
      }

      if isLoading && !cachedVisibleRecords.isEmpty {
        VStack(spacing: 8) {
          ProgressView()
            .scaleEffect(1.0)
          Text(String(localized: "preparing_data", table: "Home"))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .allowsHitTesting(false)
      }
    }
    .onAppear {
      let startTime = CFAbsoluteTimeGetCurrent()
      print("[Performance] AnalyticsContentView.onAppear開始")

      prepareFilteredRecordsIfNeeded()

      let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
      print("[Performance] AnalyticsContentView.onAppear完了: \(String(format: "%.2f", elapsed))ms")
    }
    .onChange(of: records) {
      prepareFilteredRecordsIfNeeded()
    }
    .onChange(of: selectedDevice) {
      prepareFilteredRecordsIfNeeded()
    }
    .onChange(of: windowEnd) {
      prepareChartDataIfNeeded()
    }
    .onChange(of: selectedRange) {
      prepareChartDataIfNeeded()
    }
  }

  // MARK: - フィルタ済みレコードを準備
  private func prepareFilteredRecordsIfNeeded() {
    let startTime = CFAbsoluteTimeGetCurrent()

    let quickSignature = Self.quickSignature(records: records, selectedDevice: selectedDevice)
    if quickSignature == lastQuickSignature, !cachedFilteredRecords.isEmpty {
      print("[Performance] prepareFilteredRecordsIfNeededスキップ（キャッシュ有効）")
      return
    }

    print("[Performance] prepareFilteredRecordsIfNeeded開始")
    isLoading = true

    if let device = selectedDevice {
      cachedFilteredRecords = records.filter { $0.deviceName == device }
    } else {
      cachedFilteredRecords = records
    }

    lastQuickSignature = quickSignature

    let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
    print("[Performance] prepareFilteredRecordsIfNeeded完了: \(String(format: "%.2f", elapsed))ms")

    prepareChartDataIfNeeded()
  }

  // MARK: - バックグラウンドでチャートデータを準備
  @MainActor
  private func prepareChartDataIfNeeded() {
    let startTime = CFAbsoluteTimeGetCurrent()

    // パラメータのハッシュを計算
    var hasher = Hasher()
    for record in cachedFilteredRecords {
      hasher.combine(record.logDate)
      hasher.combine(record.deviceName)
    }
    hasher.combine(windowEnd)
    hasher.combine(selectedRange)
    hasher.combine(selectedDevice)
    let parametersHash = hasher.finalize()

    // 変更がなければスキップ
    if parametersHash == lastParametersHash {
      print("[Performance] prepareChartDataIfNeededスキップ（パラメータ未変更）")
      return
    }

    print("[Performance] prepareChartDataIfNeeded開始")
    isLoading = true

    // 日付配列を抽出（Sendable対応）
    let recordDates = cachedFilteredRecords.map { $0.logDate }
    let currentWindowEnd = windowEnd
    let currentRange = selectedRange

    // ウィンドウ計算はMainActorで実行（軽量）
    let result = computeWindow(
      recordDates: recordDates,
      windowEnd: currentWindowEnd,
      range: currentRange
    )

    DispatchQueue.global(qos: .userInitiated).async {
      // 可視インデックスをバックグラウンドで計算
      let calendar = Calendar.current
      let startDay = result.startDay
      let endDay = result.endDay
      let visibleIndexes = recordDates.enumerated().compactMap { index, date in
        let d = calendar.startOfDay(for: date)
        return (d >= startDay && d <= endDay) ? index : nil
      }

      DispatchQueue.main.async {
        // 計算結果に基づいてfilteredRecordsからvisibleRecordsを取得
        cachedVisibleRecords = visibleIndexes.map { cachedFilteredRecords[$0] }
        cachedStartDay = result.startDay
        cachedEndDay = result.endDay
        cachedUnit = result.unit
        lastParametersHash = parametersHash
        isLoading = false

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("[Performance] prepareChartDataIfNeeded完了: \(String(format: "%.2f", elapsed))ms")
      }
    }
  }

  @MainActor
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

  private static func quickSignature(
    records: [BatteryRecord],
    selectedDevice: String?
  ) -> Int {
    var hasher = Hasher()
    hasher.combine(records.count)
    hasher.combine(records.first?.logDate)
    hasher.combine(records.last?.logDate)
    if records.count > 2 {
      hasher.combine(records[records.count / 2].logDate)
    }
    hasher.combine(selectedDevice)
    return hasher.finalize()
  }

}
