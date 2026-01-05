import SwiftData
import SwiftUI

// MARK: - 分析ビュー
struct AnalyticsView: View {
  @Query(sort: \BatteryRecord.logDate, order: .forward) private var records: [BatteryRecord]
  @State private var selectedDevice: String?
  @StateObject private var appSettings = AppSettings.shared

  @State private var selectedRange: RangePreset = .oneMonth
  // 表示ウィンドウの終了日時（endDate）。範囲を前後に移動すると変更される。デフォルトは現在時刻。
  @State private var windowEnd: Date = Date()

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var animateChart: Bool = false

  @State private var viewportHeight: CGFloat = 0
  @State private var showingTutorial = false

  private var deviceNames: [String] {
    Array(Set(records.map { $0.deviceName })).sorted()
  }

  private var filteredRecords: [BatteryRecord] {
    guard let device = selectedDevice else { return records }
    return records.filter { $0.deviceName == device }
  }

  /// データの分布に基づいて初期レンジを決定する（短い期間しかなければ小さいレンジを選ぶ）
  private func autoRange(for records: [BatteryRecord]) -> RangePreset {
    guard let first = records.min(by: { $0.logDate < $1.logDate })?.logDate,
      let last = records.max(by: { $0.logDate < $1.logDate })?.logDate
    else { return .oneMonth }

    let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0

    if days <= 7 { return .oneWeek }
    if days <= 30 { return .oneMonth }
    if days <= 90 { return .threeMonths }
    if days <= 180 { return .sixMonths }
    if days <= 365 { return .oneYear }
    if days <= 730 { return .twoYears }
    return .all
  }

  /// レコードに応じて表示単位（Hour/Day/Week/Month）を自動決定する
  private func autoUnit(for records: [BatteryRecord], range: RangePreset) -> AppSettings.ChartUnit {
    guard !records.isEmpty else { return .day }

    let first = records.min(by: { $0.logDate < $1.logDate })!.logDate
    let last = records.max(by: { $0.logDate < $1.logDate })!.logDate
    let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
    let count = records.count

    // 短い期間で多数のサンプルがある場合は hour
    if days <= 2 && count > 24 { return .hour }
    // 2週間以下は day が見やすい
    if days <= 14 { return .day }
    // 4ヶ月以下は週次表示
    if days <= 120 { return .week }
    // それ以上は月次表示
    return .month
  }

  // MARK: - ウィンドウ（前後移動）ヘルパー - 共通ユーティリティを使用

  private func windowStart(for endDate: Date, range: RangePreset) -> Date {
    ChartWindowNavigator.windowStart(for: endDate, range: range, allRecords: filteredRecords)
  }

  private func windowContainsData(start: Date, end: Date, in records: [BatteryRecord]) -> Bool {
    ChartWindowNavigator.windowContainsData(start: start, end: end, in: records)
  }

  /// 初期化時・レンジ変更時に、現在時点や最終記録を考慮して表示ウィンドウの終了日時を決める
  private func initializeWindowEndIfNeeded() {
    windowEnd = ChartWindowNavigator.initializeWindowEnd(for: filteredRecords, range: selectedRange)
  }

  private func shiftWindow(backward: Bool) {
    windowEnd = ChartWindowNavigator.shiftWindow(
      currentEnd: windowEnd,
      backward: backward,
      range: selectedRange,
      records: filteredRecords
    )
  }

  // MARK: - 前後移動の可否
  private var canMoveNext: Bool {
    ChartWindowNavigator.canMoveNext(
      currentEnd: windowEnd, range: selectedRange, records: filteredRecords)
  }
  private var canMovePrevious: Bool {
    ChartWindowNavigator.canMovePrevious(
      currentEnd: windowEnd, range: selectedRange, records: filteredRecords)
  }

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        if appSettings.showingSampleData {
          // サンプルモードON → サンプルグラフ表示
          ScrollView {
            SampleDataAnalyticsContent(
              showingSampleData: $appSettings.showingSampleData,
              animateChart: $animateChart,
              selectedRange: $selectedRange
            )
          }
        } else if !records.isEmpty {
          ScrollView {
            VStack(spacing: 20) {
              // デバイス選択ピッカー
              DevicePickerView(deviceNames: deviceNames, selectedDevice: $selectedDevice)

              // 共通の期間計算（ヘルス・サイクルで共用）
              let end = windowEnd
              let calendar = Calendar.current
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
                case .all:
                  return (filteredRecords.min(by: { $0.logDate < $1.logDate })?.logDate) ?? end
                }
              }()

              let startDay = calendar.startOfDay(for: startDate)
              let endDay = calendar.startOfDay(for: end)
              let visibleRecords = filteredRecords.filter {
                let d = calendar.startOfDay(for: $0.logDate)
                return d >= startDay && d <= endDay
              }

              let unit = autoUnit(for: visibleRecords, range: selectedRange)

              // iPad: 2列レイアウト、iPhone: 1列レイアウト
              if horizontalSizeClass == .regular {
                // iPad向け：グラフと統計を同じ幅にまとめる
                VStack(spacing: 20) {
                  // iPad向け2列グリッド
                  HStack(alignment: .top, spacing: 20) {
                    // ヘルス推移グラフ
                    HealthTrendView(
                      visibleRecords: visibleRecords,
                      startDay: startDay,
                      endDay: endDay,
                      unit: unit,
                      selectedRange: $selectedRange,
                      canMoveNext: canMoveNext,
                      canMovePrevious: canMovePrevious,
                      shiftWindow: shiftWindow,
                      animateChart: $animateChart
                    )

                    // サイクル推移グラフ
                    CycleTrendView(
                      allRecords: filteredRecords,
                      unit: unit,
                      animateChart: $animateChart
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
                  visibleRecords: visibleRecords,
                  startDay: startDay,
                  endDay: endDay,
                  unit: unit,
                  selectedRange: $selectedRange,
                  canMoveNext: canMoveNext,
                  canMovePrevious: canMovePrevious,
                  shiftWindow: shiftWindow,
                  animateChart: $animateChart
                )

                // サイクル推移グラフ
                CycleTrendView(
                  allRecords: filteredRecords,
                  unit: unit,
                  animateChart: $animateChart
                )

                // 統計情報（iPhone）
                if !filteredRecords.isEmpty {
                  StatisticsView(filteredRecords: filteredRecords)
                }
              }
            }
            .padding()
          }
        } else {
          // データなし + サンプルモードOFF → ボタン表示（中央配置）
          GeometryReader { geo in
            ScrollView {
              ContentUnavailableView {
                Label(
                  String(localized: "no_data", table: "Home"),
                  systemImage: "chart.line.uptrend.xyaxis")
              } description: {
                Text(String(localized: "no_data_description", table: "Home"))
              } actions: {
                VStack(spacing: 12) {
                  Button {
                    showingTutorial = true
                  } label: {
                    Label(
                      String(localized: "view_tutorial", table: "Home"), systemImage: "play.circle")
                  }
                  .buttonStyle(.bordered)

                  Button {
                    withAnimation { appSettings.showingSampleData = true }
                  } label: {
                    Label(String(localized: "view_sample_data", table: "Home"), systemImage: "eye")
                  }
                  .buttonStyle(.borderedProminent)
                }
              }
              .frame(maxWidth: .infinity)
              // 「実スクロール」を作らないため、viewportより 1pt 小さくする
              .frame(minHeight: max(0, viewportHeight - 1))
            }
            .scrollBounceBehavior(.always)  // バウンスは常に有効
            .onAppear {
              viewportHeight = geo.size.height
            }
            .onChange(of: geo.size.height) { oldValue, newValue in
              // 回転など「大きい変化」だけ追従。Large Title の伸縮由来の揺れは無視。
              if abs(newValue - viewportHeight) > 80 {
                viewportHeight = newValue
              }
            }
          }
        }
      }
      .onAppear {
        // 起動セッション内で一度だけ、現在の（フィルタ済み）データに合わせてレンジを自動設定（ユーザー選択は上書きしない）
        if !appSettings.hasAutoInitializedChartRange {
          selectedRange = autoRange(for: filteredRecords)
          initializeWindowEndIfNeeded()
          appSettings.hasAutoInitializedChartRange = true
        } else {
          // 既にセッション内で初期化済みなら、現在のウィンドウがデータを含むか確認し、必要なら調整
          initializeWindowEndIfNeeded()
        }
      }
      .onChange(of: records) {
        // records 更新時に、まだセッション内で自動初期化が済んでいなければ適用
        if !appSettings.hasAutoInitializedChartRange {
          selectedRange = autoRange(for: filteredRecords)
          initializeWindowEndIfNeeded()
          appSettings.hasAutoInitializedChartRange = true
        } else {
          // 変更により現在ウィンドウにデータがなくなった場合はウィンドウを調整
          let start = windowStart(for: windowEnd, range: selectedRange)
          if !windowContainsData(start: start, end: windowEnd, in: filteredRecords) {
            initializeWindowEndIfNeeded()
          }
        }
      }
      .onChange(of: selectedDevice) {
        // デバイス切替時もセッション内の初回のみ適用（既に初期化済みならユーザー選択を尊重）
        if !appSettings.hasAutoInitializedChartRange {
          selectedRange = autoRange(for: filteredRecords)
          initializeWindowEndIfNeeded()
          appSettings.hasAutoInitializedChartRange = true
        } else {
          let start = windowStart(for: windowEnd, range: selectedRange)
          if !windowContainsData(start: start, end: windowEnd, in: filteredRecords) {
            initializeWindowEndIfNeeded()
          }
        }
      }
      .navigationTitle(String(localized: "analytics", table: "Analytics"))
      .background(Color(.systemGroupedBackground))
      .sheet(isPresented: $showingTutorial) {
        TutorialView()
      }
    }
  }

  private func healthColor(_ percent: Double) -> Color {
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return appSettings.accentColor.color
  }
}

#Preview {
  AnalyticsView()
    .modelContainer(for: BatteryRecord.self, inMemory: true)
}
