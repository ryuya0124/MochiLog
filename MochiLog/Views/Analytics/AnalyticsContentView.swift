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
  @State private var cachedVisibleRecords: [BatteryRecord] = []  // 統計用（期間内のみ）
  @State private var cachedChartRecords: [BatteryRecord] = []  // グラフ用（前後バッファ付き）
  @State private var cachedAllDeviceNames: [String] = []  // チャート用デバイス名（cachedChartRecordsと同期）
  @State private var cachedStartDay: Date = Date()
  @State private var cachedEndDay: Date = Date()
  @State private var cachedUnit: AppSettings.ChartUnit = .day
  @State private var lastQuickSignature: Int?
  @State private var lastParametersHash: Int?
  @State private var isPreparingChartData: Bool = false
  @State private var pendingParametersHash: Int?

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
    let _ = print(
      "[Performance] AnalyticsContentView.body構築 - isLoading: \(isLoading), cachedVisibleRecords: \(cachedVisibleRecords.count)件"
    )

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
                    visibleRecords: cachedChartRecords,
                    startDay: cachedStartDay,
                    endDay: cachedEndDay,
                    unit: cachedUnit,
                    selectedRange: $selectedRange,
                    canMoveNext: canMoveNext,
                    canMovePrevious: canMovePrevious,
                    shiftWindow: shiftWindow,
                    allDeviceNames: cachedAllDeviceNames
                  )

                  // サイクル推移グラフ
                  CycleTrendView(
                    allRecords: cachedFilteredRecords,
                    unit: cachedUnit,
                    initialRange: selectedRange,
                    allDeviceNames: cachedAllDeviceNames
                  )
                }

                // 統計情報（iPad）
                if !cachedFilteredRecords.isEmpty {
                  StatisticsView(filteredRecords: cachedVisibleRecords)
                }
              }
              .frame(maxWidth: 1200)
            } else {
              // iPhone向け1列レイアウト
              // ヘルス推移グラフ
              HealthTrendView(
                visibleRecords: cachedChartRecords,
                startDay: cachedStartDay,
                endDay: cachedEndDay,
                unit: cachedUnit,
                selectedRange: $selectedRange,
                canMoveNext: canMoveNext,
                canMovePrevious: canMovePrevious,
                shiftWindow: shiftWindow,
                allDeviceNames: cachedAllDeviceNames
              )

              // サイクル推移グラフ（iPhoneでは親と期間を共有）
              CycleTrendView(
                allRecords: cachedFilteredRecords,
                unit: cachedUnit,
                initialRange: selectedRange, allDeviceNames: cachedAllDeviceNames,
                sharedSelectedRange: $selectedRange,
                sharedWindowEnd: $windowEnd,
                sharedCanMoveNext: canMoveNext,
                sharedCanMovePrevious: canMovePrevious,
                sharedShiftWindow: shiftWindow,
                sharedWindowEndValue: windowEnd
              )

              // 統計情報（iPhone）
              if !cachedFilteredRecords.isEmpty {
                StatisticsView(filteredRecords: cachedVisibleRecords)
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
    .onChange(of: records) { _ in
      prepareFilteredRecordsIfNeeded()
    }
    .onChange(of: selectedDevice) { _ in
      prepareFilteredRecordsIfNeeded()
    }
    .onChange(of: windowEnd) { _ in
      prepareChartDataIfNeeded()
    }
    .onChange(of: selectedRange) { _ in
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

    // パラメータの同値チェック（Hasherを1インスタンスで完結させることでiOS 16の再現性を保証）
    let parametersHash = Self.makeParametersHash(
      records: cachedFilteredRecords,
      windowEnd: windowEnd,
      selectedRange: selectedRange,
      selectedDevice: selectedDevice
    )

    // 変更がなければスキップ
    if parametersHash == lastParametersHash {
      print("[Performance] prepareChartDataIfNeededスキップ（パラメータ未変更）")
      return
    }

    if isPreparingChartData {
      pendingParametersHash = parametersHash
      print("[Performance] prepareChartDataIfNeeded保留（処理中）- メインスレッドブロック対策")
      return
    }

    print(
      "[Performance] prepareChartDataIfNeeded開始 - records: \(cachedFilteredRecords.count)件, range: \(selectedRange.rawValue)"
    )
    isPreparingChartData = true
    isLoading = true

    // スナップショットを取得（デバイス切り替え時のクラッシュ防止）
    let filteredSnapshot = cachedFilteredRecords
    let recordDates = filteredSnapshot.map { $0.logDate }
    let currentWindowEnd = windowEnd
    let currentRange = selectedRange
    let capturedSelectedDevice = selectedDevice

    // 全デバイス名を全レコードから計算（色を固定するため、フィルタ前のデータを使用）
    let allDeviceNamesSnapshot = Array(Set(records.map { $0.deviceName })).sorted()

    // ウィンドウ計算はMainActorで実行（軽量）
    let windowStartTime = CFAbsoluteTimeGetCurrent()
    let result = computeWindow(
      recordDates: recordDates,
      windowEnd: currentWindowEnd,
      range: currentRange
    )
    let windowElapsed = (CFAbsoluteTimeGetCurrent() - windowStartTime) * 1000
    print(
      "[Performance] prepareChartDataIfNeeded - ウィンドウ計算: \(String(format: "%.2f", windowElapsed))ms"
    )

    // Task.detached で非同期実行（DispatchQueue + @MainActor の混在を排除）
    Task.detached(priority: .userInitiated) {
      let bgStartTime = CFAbsoluteTimeGetCurrent()

      // 可視インデックスをバックグラウンドで計算
      let calendar = Calendar.current
      let startDay = result.startDay
      let endDay = result.endDay
      let visibleIndexes = recordDates.enumerated().compactMap { index, date -> Int? in
        let d = calendar.startOfDay(for: date)
        return (d >= startDay && d <= endDay) ? index : nil
      }

      let bgElapsed = (CFAbsoluteTimeGetCurrent() - bgStartTime) * 1000
      print(
        "[Performance] prepareChartDataIfNeeded - バックグラウンド処理: \(String(format: "%.2f", bgElapsed))ms, 可視レコード: \(visibleIndexes.count)件"
      )

      // MainActor に戻って UI 更新
      await MainActor.run {
        let uiUpdateStartTime = CFAbsoluteTimeGetCurrent()

        let visibleStart = result.startDay
        let visibleEnd = result.endDay

        // 統計用
        cachedVisibleRecords = visibleIndexes.map { filteredSnapshot[$0] }

        // チャート描画用
        cachedChartRecords = ChartWindowNavigator.visibleRecordsWithContext(
          in: filteredSnapshot,
          start: visibleStart,
          end: visibleEnd
        )

        cachedStartDay = visibleStart
        cachedEndDay = visibleEnd
        cachedUnit = result.unit
        cachedAllDeviceNames = allDeviceNamesSnapshot
        lastParametersHash = parametersHash

        let uiUpdateElapsed = (CFAbsoluteTimeGetCurrent() - uiUpdateStartTime) * 1000
        let totalElapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print(
          "[Performance] prepareChartDataIfNeeded - UI更新: \(String(format: "%.2f", uiUpdateElapsed))ms"
        )
        print(
          "[Performance] prepareChartDataIfNeeded完了（合計）: \(String(format: "%.2f", totalElapsed))ms"
        )
        print("[Performance] isLoadingをfalseに設定")

        isLoading = false
        isPreparingChartData = false

        // 完了後に現在値を同じハッシュ関数で再計算し、変化があれば再実行
        let currentHash = Self.makeParametersHash(
          records: cachedFilteredRecords,
          windowEnd: windowEnd,
          selectedRange: selectedRange,
          selectedDevice: capturedSelectedDevice
        )

        if parametersHash != currentHash || pendingParametersHash != nil {
          pendingParametersHash = nil
          print("[Performance] prepareChartDataIfNeeded - パラメータ変更検出、再実行")
          prepareChartDataIfNeeded()
        }
      }
    }
  }

  /// パラメータハッシュを計算（同一入力で常に同じ値を返す安定ハッシュ）
  private static func makeParametersHash(
    records: [BatteryRecord],
    windowEnd: Date,
    selectedRange: RangePreset,
    selectedDevice: String?
  ) -> Int {
    var hasher = Hasher()
    hasher.combine(records.count)
    hasher.combine(records.first?.logDate)
    hasher.combine(records.last?.logDate)
    hasher.combine(windowEnd)
    hasher.combine(selectedRange)
    hasher.combine(selectedDevice)
    return hasher.finalize()
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
