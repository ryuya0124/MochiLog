import SwiftUI

/// 分析画面のコンテンツビュー（バックグラウンドでデータ準備）
/// AnalyticsViewから使用される実データ表示用のコンポーネント
struct AnalyticsContentView: View {
  let records: [BatteryRecord]
  let selectedDevice: String?
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

              // サイクル推移グラフ
              CycleTrendView(
                allRecords: filteredRecords,
                unit: cachedUnit,
                initialRange: selectedRange
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
    let calendar = Calendar.current
    let end = windowEnd

    // 開始日を計算
    let startDate: Date = {
      switch selectedRange {
      case .oneWeek:
        return calendar.date(byAdding: .day, value: -7, to: end) ?? end
      case .oneMonth:
        return calendar.date(byAdding: .month, value: -1, to: end) ?? end
      case .threeMonths:
        return calendar.date(byAdding: .month, value: -3, to: end) ?? end
      case .sixMonths:
        return calendar.date(byAdding: .month, value: -6, to: end) ?? end
      case .oneYear:
        return calendar.date(byAdding: .year, value: -1, to: end) ?? end
      case .twoYears:
        return calendar.date(byAdding: .year, value: -2, to: end) ?? end
      case .threeYears:
        return calendar.date(byAdding: .year, value: -3, to: end) ?? end
      }
    }()

    let startDay = calendar.startOfDay(for: startDate)
    let endDay = calendar.startOfDay(for: end)

    // 期間内のレコードをフィルタリング
    let visibleInfos = recordInfos.filter { info in
      let d = calendar.startOfDay(for: info.logDate)
      return d >= startDay && d <= endDay
    }

    // 表示単位を自動決定
    let unit = autoUnit(for: visibleInfos)

    return (startDay, endDay, unit)
  }

  /// レコードに応じて表示単位を自動決定する
  nonisolated private static func autoUnit(for recordInfos: [(logDate: Date, deviceName: String)])
    -> AppSettings.ChartUnit
  {
    guard !recordInfos.isEmpty else { return .day }

    let calendar = Calendar.current
    let first = recordInfos.min(by: { $0.logDate < $1.logDate })!.logDate
    let last = recordInfos.max(by: { $0.logDate < $1.logDate })!.logDate
    let days = calendar.dateComponents([.day], from: first, to: last).day ?? 0
    let count = recordInfos.count

    // 短い期間で多数のサンプルがある場合は hour
    if days <= 2 && count > 24 { return .hour }
    // 2週間以下は day が見やすい
    if days <= 14 { return .day }
    // 4ヶ月以下は週次表示
    if days <= 120 { return .week }
    // それ以上は月次表示
    return .month
  }
}
