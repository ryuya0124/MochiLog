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
  @State private var showingSampleData: Bool = false

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

  // MARK: - ウィンドウ（前後移動）ヘルパー
  private func periodComponent(for preset: RangePreset) -> DateComponents? {
    switch preset {
    case .oneWeek:
      return DateComponents(day: 7)
    case .oneMonth:
      return DateComponents(month: 1)
    case .threeMonths:
      return DateComponents(month: 3)
    case .all:
      return nil
    }
  }

  private func windowStart(for endDate: Date, range: RangePreset) -> Date {
    let calendar = Calendar.current
    switch range {
    case .oneWeek:
      return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
    case .oneMonth:
      return calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
    case .threeMonths:
      return calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
    case .all:
      return (filteredRecords.min(by: { $0.logDate < $1.logDate })?.logDate) ?? endDate
    }
  }

  private func windowContainsData(start: Date, end: Date, in records: [BatteryRecord]) -> Bool {
    let cal = Calendar.current
    let startDay = cal.startOfDay(for: start)
    let endDay = cal.startOfDay(for: end)
    return records.contains {
      let d = cal.startOfDay(for: $0.logDate)
      return d >= startDay && d <= endDay
    }
  }

  /// 初期化時・レンジ変更時に、現在時点や最終記録を考慮して表示ウィンドウの終了日時を決める
  private func initializeWindowEndIfNeeded() {
    guard !filteredRecords.isEmpty else {
      windowEnd = Date()
      return
    }

    // all のときは最新記録までを表示
    if selectedRange == .all {
      windowEnd = filteredRecords.max(by: { $0.logDate < $1.logDate })?.logDate ?? Date()
      return
    }

    // 通常は現在時刻を優先して、ウィンドウ内にデータが含まれるか確認
    let now = Date()
    let startNow = windowStart(for: now, range: selectedRange)
    if windowContainsData(start: startNow, end: now, in: filteredRecords) {
      windowEnd = now
      return
    }

    // そうでなければ最後の記録日時をウィンドウ終了にする
    if let last = filteredRecords.max(by: { $0.logDate < $1.logDate })?.logDate {
      windowEnd = last
    } else {
      windowEnd = now
    }
  }

  /// 前方に移動できるウィンドウ（endDate）を探す（返り値は新しい endDate）
  private func findNextWindowEnd() -> Date? {
    guard let comp = periodComponent(for: selectedRange) else { return nil }
    var candidateEnd = windowEnd
    let now = Date()

    // 移動先は現在より未来にならないようにする
    while true {
      guard let nextEnd = Calendar.current.date(byAdding: comp, to: candidateEnd) else { break }
      // 次のウィンドウが現在時刻を超える場合、終了日時は現在時刻に合わせる
      let endLimited = min(nextEnd, now)
      // すでに前と同じ位置なら進めない
      if endLimited <= candidateEnd { break }

      let start = windowStart(for: endLimited, range: selectedRange)
      if windowContainsData(start: start, end: endLimited, in: filteredRecords) {
        return endLimited
      }
      // 進めてもデータが見つからない場合は次へ
      if endLimited >= now { break }
      candidateEnd = endLimited
    }
    return nil
  }

  /// 後方に移動できるウィンドウ（endDate）を探す
  private func findPreviousWindowEnd() -> Date? {
    guard let comp = periodComponent(for: selectedRange) else { return nil }
    var candidateEnd = windowEnd

    while true {
      // comp を負数で加算するヘルパーを使って後退
      guard let prevEnd = dateByAdding(comp, multiplier: -1, to: candidateEnd) else { break }
      let prevStart = windowStart(for: prevEnd, range: selectedRange)
      if windowContainsData(start: prevStart, end: prevEnd, in: filteredRecords) {
        return prevEnd
      }
      // 到達点: prevEnd が最古の記録より前なら打ち切り
      if let earliest = filteredRecords.min(by: { $0.logDate < $1.logDate })?.logDate,
        prevEnd <= earliest
      {
        break
      }
      candidateEnd = prevEnd
    }
    return nil
  }

  private func shiftWindow(backward: Bool) {
    if backward {
      if let prev = findPreviousWindowEnd() {
        windowEnd = prev
      }
    } else {
      if let next = findNextWindowEnd() {
        windowEnd = next
      }
    }
  }

  // MARK: - 前後移動の可否
  private var canMoveNext: Bool { selectedRange != .all && findNextWindowEnd() != nil }
  private var canMovePrevious: Bool { selectedRange != .all && findPreviousWindowEnd() != nil }

  /// comp を multiplier 倍して date に加算して返す（DateComponents を簡単に +/- で使えるようにする）
  private func dateByAdding(_ comp: DateComponents, multiplier: Int, to date: Date) -> Date? {
    var c = DateComponents()
    if let d = comp.day { c.day = d * multiplier }
    if let m = comp.month { c.month = m * multiplier }
    if let h = comp.hour { c.hour = h * multiplier }
    return Calendar.current.date(byAdding: c, to: date)
  }

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        if records.isEmpty && !showingSampleData {
          // データなし + サンプルモードOFF → ボタン表示（縦中央配置）
          VStack {
            Spacer()
            VStack(spacing: 16) {
              ContentUnavailableView(
                String(localized: "no_data"),
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text(String(localized: "no_data_description"))
              )
              Button {
                withAnimation {
                  showingSampleData = true
                }
              } label: {
                Label(String(localized: "view_sample_data"), systemImage: "eye")
              }
              .buttonStyle(.borderedProminent)
            }
            Spacer()
          }
          .frame(width: geometry.size.width, height: geometry.size.height)
        } else if records.isEmpty && showingSampleData {
          // データなし + サンプルモードON → サンプルグラフ表示
          ScrollView {
            SampleDataAnalyticsContent(
              showingSampleData: $showingSampleData,
              animateChart: $animateChart,
              selectedRange: $selectedRange
            )
          }
        } else {
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
                visibleRecords: visibleRecords,
                startDay: startDay,
                endDay: endDay,
                unit: unit,
                animateChart: $animateChart
              )

              // 統計情報
              if !filteredRecords.isEmpty {
                StatisticsView(filteredRecords: filteredRecords)
              }
            }
            .padding()
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
      .onChange(of: records) { _ in
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
      .onChange(of: selectedDevice) { _ in
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
      .navigationTitle(String(localized: "analytics"))
      .background(Color(.systemGroupedBackground))
    }
  }

  private var averageHealth: Double {
    guard !filteredRecords.isEmpty else { return 0 }
    let total = filteredRecords.reduce(0) { $0 + $1.realHealthPercent }
    return total / Double(filteredRecords.count)
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
