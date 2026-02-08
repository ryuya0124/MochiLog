import Combine
import SwiftData
import SwiftUI

// MARK: - 分析ビュー
struct AnalyticsView: View {
  @State private var selectedDevice: String?
  private let appSettings = AppSettings.shared
  @State private var recordDataManager = RecordDataManager.shared

  @State private var selectedRange: RangePreset = .oneMonth
  // 表示ウィンドウの終了日時（endDate）。範囲を前後に移動すると変更される。デフォルトは現在時刻。
  @State private var windowEnd: Date = Date()

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var viewportHeight: CGFloat = 0
  @State private var showingTutorial = false
  @State private var showingSampleData = AppSettings.shared.showingSampleData
  @State private var isInitialized = false  // 初回表示完了フラグ

  /// RecordDataManagerからレコードを取得（キャッシュ済み、昇順）
  private var records: [BatteryRecord] {
    recordDataManager.recordsAscending
  }

  /// RecordDataManagerからデバイス名リストを取得（キャッシュ済み）
  private var cachedDeviceNames: [String] {
    recordDataManager.deviceNames
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
    return .threeYears
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

  var body: some View {
    let bodyStartTime = CFAbsoluteTimeGetCurrent()
    let _ = print("[Performance] AnalyticsView.body構築開始 - records: \(records.count)件")
    let _ = print(
      "[Redraw] AnalyticsView states - showingSampleData: \(showingSampleData), selectedRange: \(selectedRange.rawValue), selectedDevice: \(selectedDevice ?? "nil")"
    )

    return NavigationStack {
      analyticsContent
        .onAppear {
          let appearStartTime = CFAbsoluteTimeGetCurrent()
          let bodyElapsed = (appearStartTime - bodyStartTime) * 1000
          print(
            "[Performance] AnalyticsView.onAppear開始 (body構築から: \(String(format: "%.2f", bodyElapsed))ms)"
          )

          initializeViewIfNeeded()
          isInitialized = true  // 初回表示完了を記録

          let appearElapsed = (CFAbsoluteTimeGetCurrent() - appearStartTime) * 1000
          let totalElapsed = (CFAbsoluteTimeGetCurrent() - bodyStartTime) * 1000
          print(
            "[Performance] AnalyticsView.onAppear完了: \(String(format: "%.2f", appearElapsed))ms")
          print("[Performance] AnalyticsView 合計初期化時間: \(String(format: "%.2f", totalElapsed))ms")
        }
        .onChange(of: selectedDevice) {
          handleDeviceChange()
        }
        .onChange(of: selectedRange) { _, newValue in
          print("[Redraw] selectedRange onChange: \(newValue.rawValue)")
          // ガード: 既に同じ値なら何もしない
          guard appSettings.selectedChartRange != newValue.rawValue else {
            print("[Performance] selectedRange onChange スキップ（既に同じ値）")
            return
          }

          // レンジ変更時にAppSettingsに保存（再起動後も保持）
          appSettings.selectedChartRange = newValue.rawValue

          // レンジ変更時に終了日を適切に更新
          let filteredRecords =
            selectedDevice.map { device in records.filter { $0.deviceName == device } } ?? records

          windowEnd = ChartWindowNavigator.adjustedWindowEndForRangeChange(
            range: newValue,
            currentEnd: windowEnd,
            records: filteredRecords
          )
        }
        .onChange(of: showingSampleData) { _, newValue in
          print("[Redraw] showingSampleData onChange: \(newValue)")
          // ガード: 既に同じ値なら何もしない
          guard appSettings.showingSampleData != newValue else {
            print("[Performance] showingSampleData onChange スキップ（既に同じ値）")
            return
          }
          appSettings.showingSampleData = newValue
        }
        .onReceive(appSettings.$showingSampleData.removeDuplicates()) { newValue in
          if showingSampleData != newValue {
            showingSampleData = newValue
          }
        }
        .navigationTitle(String(localized: "analytics", table: "Analytics"))
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingTutorial) {
          TutorialView()
        }
    }
  }

  // MARK: - メインコンテンツ
  @ViewBuilder
  private var analyticsContent: some View {
    let _ = print("[Performance] analyticsContent構築開始")

    if showingSampleData {
      let _ = print("[Performance] analyticsContent: サンプルモード分岐")
      // サンプルモードON → サンプルグラフ表示
      ScrollView {
        SampleDataAnalyticsContent(
          showingSampleData: $showingSampleData,
          selectedRange: $selectedRange
        )
      }
    } else if !records.isEmpty {
      let _ = print("[Performance] analyticsContent: 実データ表示分岐 - records: \(records.count)件")
      // コンテンツビュー（バックグラウンドでデータ計算）
      AnalyticsContentView(
        records: records,
        selectedDevice: $selectedDevice,
        cachedDeviceNames: cachedDeviceNames,  // キャッシュから取得
        selectedRange: $selectedRange,
        windowEnd: $windowEnd
      )
    } else {
      let _ = print("[Performance] analyticsContent: データなし分岐")
      // データなし + サンプルモードOFF → ボタン表示（中央配置）
      // GeometryReaderはここだけで使用
      GeometryReader { geometry in
        noDataView(geometry: geometry)
      }
    }
  }

  // MARK: - データなしビュー
  @ViewBuilder
  private func noDataView(geometry: GeometryProxy) -> some View {
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

  // MARK: - 初期化処理
  private func initializeViewIfNeeded() {
    // サンプルモードまたはデータがない場合は何もしない
    guard !showingSampleData && !records.isEmpty else { return }

    // 保存されたレンジがあればそれを使用、なければ自動選択
    if let savedRangeString = appSettings.selectedChartRange,
      let savedRange = RangePreset(rawValue: savedRangeString)
    {
      selectedRange = savedRange
    } else if !appSettings.hasAutoInitializedChartRange {
      selectedRange = calculateAutoRange(for: records)
      appSettings.hasAutoInitializedChartRange = true
    }

    // ウィンドウ終了日を設定
    windowEnd = ChartWindowNavigator.initializeWindowEnd(for: records, range: selectedRange)
  }

  /// バックグラウンドスレッドで安全に呼べるautoRange計算
  /// 未来のデータは無視して現在日時以前のデータのみを考慮
  nonisolated private func calculateAutoRange(for records: [BatteryRecord]) -> RangePreset {
    let now = Date()
    // 未来のデータを除外
    let pastRecords = records.filter { $0.logDate <= now }

    guard let first = pastRecords.min(by: { $0.logDate < $1.logDate })?.logDate,
      let last = pastRecords.max(by: { $0.logDate < $1.logDate })?.logDate
    else { return .oneMonth }

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

  // MARK: - records変更時の処理（キャッシュから取得するため不要）
  // 削除済み

  // MARK: - デバイス変更時の処理
  private func handleDeviceChange() {
    Task.detached(priority: .userInitiated) {
      await MainActor.run {
        let filteredRecords =
          selectedDevice.map { device in records.filter { $0.deviceName == device } } ?? records

        if !appSettings.hasAutoInitializedChartRange {
          selectedRange = calculateAutoRange(for: filteredRecords)
          windowEnd = ChartWindowNavigator.initializeWindowEnd(
            for: filteredRecords, range: selectedRange)
          appSettings.hasAutoInitializedChartRange = true
        } else {
          let start = ChartWindowNavigator.windowStart(
            for: windowEnd, range: selectedRange, allRecords: filteredRecords)
          if !ChartWindowNavigator.windowContainsData(
            start: start, end: windowEnd, in: filteredRecords)
          {
            windowEnd = ChartWindowNavigator.initializeWindowEnd(
              for: filteredRecords, range: selectedRange)
          }
        }
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
