import Foundation

// MARK: - グラフウィンドウナビゲーションユーティリティ
/// グラフの期間移動に関する共通ロジック
struct ChartWindowNavigator {

  // MARK: - 期間コンポーネント

  /// 選択されたレンジに対応するDateComponentsを返す
  static func periodComponent(for preset: RangePreset) -> DateComponents? {
    switch preset {
    case .oneWeek:
      return DateComponents(day: 7)
    case .oneMonth:
      return DateComponents(month: 1)
    case .threeMonths:
      return DateComponents(month: 3)
    case .sixMonths:
      return DateComponents(month: 6)
    case .oneYear:
      return DateComponents(year: 1)
    case .twoYears:
      return DateComponents(year: 2)
    case .threeYears:
      return DateComponents(year: 3)
    }
  }

  // MARK: - ウィンドウ開始日計算

  /// 指定した終了日とレンジから開始日を計算
  static func windowStart(for endDate: Date, range: RangePreset, allRecords: [BatteryRecord])
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
    case .threeYears:
      return calendar.date(byAdding: .year, value: -3, to: endDate) ?? endDate
    }
  }

  // MARK: - データ存在チェック

  /// 指定した期間内にデータが存在するかチェック
  static func windowContainsData(start: Date, end: Date, in records: [BatteryRecord]) -> Bool {
    let cal = Calendar.current
    let startDay = cal.startOfDay(for: start)
    let endDay = cal.startOfDay(for: end)
    return records.contains {
      let d = cal.startOfDay(for: $0.logDate)
      return d >= startDay && d <= endDay
    }
  }

  // MARK: - 日付計算ヘルパー

  /// DateComponentsを倍数で加算
  static func dateByAdding(_ comp: DateComponents, multiplier: Int, to date: Date) -> Date? {
    var c = DateComponents()
    if let d = comp.day { c.day = d * multiplier }
    if let m = comp.month { c.month = m * multiplier }
    if let y = comp.year { c.year = y * multiplier }
    if let h = comp.hour { c.hour = h * multiplier }
    return Calendar.current.date(byAdding: c, to: date)
  }

  // MARK: - 次のウィンドウ検索

  /// 次の（未来方向の）ウィンドウ終了日を検索
  /// 空白期間がある場合は、次のデータがある場所に直接ジャンプする
  static func findNextWindowEnd(
    currentEnd: Date,
    range: RangePreset,
    records: [BatteryRecord]
  ) -> Date? {
    let cal = Calendar.current
    let currentEndDay = cal.startOfDay(for: currentEnd)

    // 現在のウィンドウより先にあるデータを探す
    let futureRecords = records.filter { cal.startOfDay(for: $0.logDate) > currentEndDay }
    guard let nextDataDate = futureRecords.min(by: { $0.logDate < $1.logDate })?.logDate else {
      // 現在のウィンドウより先にデータがない
      return nil
    }

    guard let comp = periodComponent(for: range) else { return nil }

    // 次のデータを含むウィンドウの終了日を決定
    // データの日付 + 選択されたレンジの期間をウィンドウの終了日とする
    var newEnd: Date
    if let endFromNextData = cal.date(byAdding: comp, to: cal.startOfDay(for: nextDataDate)) {
      newEnd = endFromNextData
    } else {
      newEnd = nextDataDate
    }

    // ウィンドウにデータが含まれることを確認
    let start = windowStart(for: newEnd, range: range, allRecords: records)
    if windowContainsData(start: start, end: newEnd, in: records) {
      return newEnd
    }

    // もしウィンドウにデータがなければ、次のデータの日付をウィンドウの終了日として使用
    return nextDataDate
  }

  // MARK: - 前のウィンドウ検索

  /// 前の（過去方向の）ウィンドウ終了日を検索
  /// 空白期間がある場合は、前のデータがある場所に直接ジャンプする
  static func findPreviousWindowEnd(
    currentEnd: Date,
    range: RangePreset,
    records: [BatteryRecord]
  ) -> Date? {
    let cal = Calendar.current

    // 現在のウィンドウの開始日を取得
    let currentStart = windowStart(for: currentEnd, range: range, allRecords: records)
    let currentStartDay = cal.startOfDay(for: currentStart)

    // 現在のウィンドウより前にあるデータを探す
    let pastRecords = records.filter { cal.startOfDay(for: $0.logDate) < currentStartDay }
    guard let prevDataDate = pastRecords.max(by: { $0.logDate < $1.logDate })?.logDate else {
      // 現在のウィンドウより前にデータがない
      return nil
    }

    // 前のデータを含むウィンドウの終了日を計算
    // 前のデータの日付をウィンドウに含むようにする
    guard let comp = periodComponent(for: range) else { return nil }

    // 前のデータを含むウィンドウの終了日を決定
    // データの日付 + 選択されたレンジの期間をウィンドウの終了日とする
    var newEnd: Date
    if let endFromPrevData = cal.date(byAdding: comp, to: cal.startOfDay(for: prevDataDate)) {
      newEnd = endFromPrevData
    } else {
      newEnd = prevDataDate
    }

    // ウィンドウにデータが含まれることを確認
    let start = windowStart(for: newEnd, range: range, allRecords: records)
    if windowContainsData(start: start, end: newEnd, in: records) {
      return newEnd
    }

    // もしウィンドウにデータがなければ、前のデータの日付をウィンドウの終了日として使用
    return prevDataDate
  }

  // MARK: - ウィンドウ移動

  /// ウィンドウを前後に移動し、新しい終了日を返す
  static func shiftWindow(
    currentEnd: Date,
    backward: Bool,
    range: RangePreset,
    records: [BatteryRecord]
  ) -> Date {
    if backward {
      return findPreviousWindowEnd(currentEnd: currentEnd, range: range, records: records)
        ?? currentEnd
    } else {
      return findNextWindowEnd(currentEnd: currentEnd, range: range, records: records) ?? currentEnd
    }
  }

  // MARK: - 移動可否判定

  /// 次へ移動可能かどうか
  static func canMoveNext(currentEnd: Date, range: RangePreset, records: [BatteryRecord]) -> Bool {
    findNextWindowEnd(currentEnd: currentEnd, range: range, records: records) != nil
  }

  /// 前へ移動可能かどうか
  static func canMovePrevious(currentEnd: Date, range: RangePreset, records: [BatteryRecord])
    -> Bool
  {
    findPreviousWindowEnd(currentEnd: currentEnd, range: range, records: records) != nil
  }

  // MARK: - 自動レンジ決定

  /// データ分布に基づいて初期レンジを決定
  static func autoRange(for records: [BatteryRecord]) -> RangePreset {
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

  // MARK: - 自動単位決定

  /// 期間に応じて表示単位を決定
  static func autoUnit(for records: [BatteryRecord], startDay: Date, endDay: Date)
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

  // MARK: - ウィンドウ終了日初期化

  /// レコードに基づいてウィンドウ終了日を初期化
  static func initializeWindowEnd(for records: [BatteryRecord], range: RangePreset) -> Date {
    guard !records.isEmpty else { return Date() }

    if range == .threeYears {
      return records.max(by: { $0.logDate < $1.logDate })?.logDate ?? Date()
    }

    let now = Date()
    let startNow = windowStart(for: now, range: range, allRecords: records)
    if windowContainsData(start: startNow, end: now, in: records) {
      return now
    }

    return records.max(by: { $0.logDate < $1.logDate })?.logDate ?? now
  }
}
