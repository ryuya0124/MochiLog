import SwiftUI

/// 分析画面のコンテンツビュー（バックグラウンドでデータ準備）
/// AnalyticsViewから使用される実データ表示用のコンポーネント
struct AnalyticsContentView: View {
  let records: [BatteryRecord]
  @Binding var selectedDevice: String?
  let cachedDeviceNames: [String]
  @Binding var selectedRange: RangePreset
  @Binding var windowEnd: Date

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  // MARK: - バックグラウンド計算用の状態
  @State private var isLoading = true
  @State private var cachedVisibleRecords: [BatteryRecord] = []
  @State private var cachedStartDay: Date = Date()
  @State private var cachedEndDay: Date = Date()
  @State private var cachedUnit: AppSettings.ChartUnit = .day
  @State private var lastParametersHash: Int?

  // MARK: - フィルタ済みレコード
  private var filteredRecords: [BatteryRecord] {
    guard let device = selectedDevice else { return records }
    return records.filter { $0.deviceName == device }
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
                    allRecords: filteredRecords,
                    unit: cachedUnit,
                    initialRange: selectedRange
                  )
                }

                // 統計情報（iPad）
                if !filteredRecords.isEmpty {
                  StatisticsView(filteredRecords: filteredRecords)
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
                allRecords: filteredRecords,
                unit: cachedUnit,
                initialRange: selectedRange,
                sharedSelectedRange: $selectedRange,
                sharedWindowEnd: $windowEnd,
                sharedCanMoveNext: canMoveNext,
                sharedCanMovePrevious: canMovePrevious,
                sharedShiftWindow: shiftWindow
              )

              // 統計情報（iPhone）
              if !filteredRecords.isEmpty {
                StatisticsView(filteredRecords: filteredRecords)
              }
            }
          }
          .padding()
        }
      }
    }
    .onAppear {
      prepareChartDataIfNeeded()
    }
    .onChange(of: records) {
      prepareChartDataIfNeeded()
    }
    .onChange(of: selectedDevice) {
      prepareChartDataIfNeeded()
    }
    .onChange(of: windowEnd) {
      prepareChartDataIfNeeded()
    }
    .onChange(of: selectedRange) {
      prepareChartDataIfNeeded()
    }
  }

  // MARK: - バックグラウンドでチャートデータを準備
  private func prepareChartDataIfNeeded() {
    // パラメータのハッシュを計算
    var hasher = Hasher()
    for record in filteredRecords {
      hasher.combine(record.logDate)
      hasher.combine(record.deviceName)
    }
    hasher.combine(windowEnd)
    hasher.combine(selectedRange)
    hasher.combine(selectedDevice)
    let parametersHash = hasher.finalize()

    // 変更がなければスキップ
    if parametersHash == lastParametersHash {
      return
    }

    isLoading = true

    // レコード情報を抽出（Sendable対応）
    let recordInfos = filteredRecords.map { record in
      (logDate: record.logDate, deviceName: record.deviceName)
    }
    let currentWindowEnd = windowEnd
    let currentRange = selectedRange

    Task.detached(priority: .userInitiated) {
      // バックグラウンドで計算
      let result = Self.computeChartData(
        recordInfos: recordInfos,
        windowEnd: currentWindowEnd,
        selectedRange: currentRange
      )

      await MainActor.run {
        // 計算結果に基づいてfilteredRecordsからvisibleRecordsを取得
        let calendar = Calendar.current
        let startDay = result.startDay
        let endDay = result.endDay
        cachedVisibleRecords = filteredRecords.filter { record in
          let d = calendar.startOfDay(for: record.logDate)
          return d >= startDay && d <= endDay
        }
        cachedStartDay = result.startDay
        cachedEndDay = result.endDay
        cachedUnit = result.unit
        lastParametersHash = parametersHash
        isLoading = false
      }
    }
  }

  /// チャートデータを計算する（バックグラウンドスレッドで安全に呼び出し可能）
  nonisolated private static func computeChartData(
    recordInfos: [(logDate: Date, deviceName: String)],
    windowEnd: Date,
    selectedRange: RangePreset
  ) -> (startDay: Date, endDay: Date, unit: AppSettings.ChartUnit) {
    let dates = recordInfos.map { $0.logDate }
    return ChartWindowNavigator.computeChartWindow(
      recordDates: dates,
      windowEnd: windowEnd,
      range: selectedRange
    )
  }
}
