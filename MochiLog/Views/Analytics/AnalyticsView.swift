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
  @State private var viewportHeight: CGFloat = 0
  @State private var showingTutorial = false

  // MARK: - 初期化処理用の状態
  @State private var isInitializing = true
  @State private var cachedDeviceNames: [String] = []

  // MARK: - computed properties を削除し、キャッシュを使用

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
    NavigationStack {
      ZStack {
        if isInitializing && !appSettings.showingSampleData {
          // 初期化中のローディング表示
          VStack(spacing: 16) {
            ProgressView()
              .scaleEffect(1.2)
            Text(String(localized: "preparing_data", table: "Home"))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          analyticsContent
        }
      }
      .onAppear {
        initializeViewIfNeeded()
      }
      .onChange(of: records) {
        handleRecordsChange()
      }
      .onChange(of: selectedDevice) {
        handleDeviceChange()
      }
      .onChange(of: selectedRange) { _, newValue in
        // レンジ変更時にAppSettingsに保存（再起動後も保持）
        appSettings.selectedChartRange = newValue.rawValue
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
    GeometryReader { geometry in
      if appSettings.showingSampleData {
        // サンプルモードON → サンプルグラフ表示
        ScrollView {
          SampleDataAnalyticsContent(
            showingSampleData: $appSettings.showingSampleData,
            selectedRange: $selectedRange
          )
        }
      } else if !records.isEmpty {
        // コンテンツビュー（バックグラウンドでデータ計算）
        AnalyticsContentView(
          records: records,
          selectedDevice: $selectedDevice,
          cachedDeviceNames: cachedDeviceNames,
          selectedRange: $selectedRange,
          windowEnd: $windowEnd
        )
      } else {
        // データなし + サンプルモードOFF → ボタン表示（中央配置）
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

  // MARK: - 初期化処理（バックグラウンドで実行）
  private func initializeViewIfNeeded() {
    // サンプルモードなら即座に表示
    if appSettings.showingSampleData {
      isInitializing = false
      return
    }

    // データがなければ即座に表示
    if records.isEmpty {
      isInitializing = false
      return
    }

    // バックグラウンドで初期化処理を実行
    let currentRecords = records
    let shouldAutoInitFlag = !appSettings.hasAutoInitializedChartRange

    Task.detached(priority: .userInitiated) {
      // デバイス名リストを計算
      let deviceNames = Array(Set(currentRecords.map { $0.deviceName })).sorted()

      // 保存されたレンジがあればそれを使用、なければ自動選択
      let savedRangeString = await MainActor.run { AppSettings.shared.selectedChartRange }
      let savedRange = savedRangeString.flatMap { RangePreset(rawValue: $0) }

      let finalRange: RangePreset
      if let saved = savedRange {
        // 保存されたレンジを使用
        finalRange = saved
      } else if shouldAutoInitFlag {
        // 自動選択
        finalRange = calculateAutoRange(for: currentRecords)
      } else {
        // 既定値
        finalRange = .oneMonth
      }

      await MainActor.run {
        cachedDeviceNames = deviceNames
        selectedRange = finalRange
        windowEnd = ChartWindowNavigator.initializeWindowEnd(for: currentRecords, range: finalRange)
        appSettings.hasAutoInitializedChartRange = true
        isInitializing = false
      }
    }
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
    if days <= 30 { return .oneMonth }
    if days <= 90 { return .threeMonths }
    if days <= 180 { return .sixMonths }
    if days <= 365 { return .oneYear }
    if days <= 730 { return .twoYears }
    return .threeYears
  }

  // MARK: - records変更時の処理
  private func handleRecordsChange() {
    // デバイス名リストを更新
    let currentRecords = records
    Task.detached(priority: .userInitiated) {
      let deviceNames = Array(Set(currentRecords.map { $0.deviceName })).sorted()

      await MainActor.run {
        cachedDeviceNames = deviceNames

        if !appSettings.hasAutoInitializedChartRange {
          selectedRange = calculateAutoRange(for: currentRecords)
          windowEnd = ChartWindowNavigator.initializeWindowEnd(
            for: currentRecords, range: selectedRange)
          appSettings.hasAutoInitializedChartRange = true
        } else {
          let filteredRecords =
            selectedDevice.map { device in currentRecords.filter { $0.deviceName == device } }
            ?? currentRecords
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
