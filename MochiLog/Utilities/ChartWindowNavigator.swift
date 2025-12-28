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
    case .all:
      return nil
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
    case .all:
      return allRecords.min(by: { $0.logDate < $1.logDate })?.logDate ?? endDate
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
  static func findNextWindowEnd(
    currentEnd: Date,
    range: RangePreset,
    records: [BatteryRecord]
  ) -> Date? {
    guard let comp = periodComponent(for: range) else { return nil }
    var candidateEnd = currentEnd
    let now = Date()

    while true {
      guard let nextEnd = Calendar.current.date(byAdding: comp, to: candidateEnd) else { break }
      let endLimited = min(nextEnd, now)
      if endLimited <= candidateEnd { break }

      let start = windowStart(for: endLimited, range: range, allRecords: records)
      if windowContainsData(start: start, end: endLimited, in: records) {
        return endLimited
      }
      if endLimited >= now { break }
      candidateEnd = endLimited
    }
    return nil
  }

  // MARK: - 前のウィンドウ検索

  /// 前の（過去方向の）ウィンドウ終了日を検索
  static func findPreviousWindowEnd(
    currentEnd: Date,
    range: RangePreset,
    records: [BatteryRecord]
  ) -> Date? {
    guard let comp = periodComponent(for: range) else { return nil }
    var candidateEnd = currentEnd

    while true {
      guard let prevEnd = dateByAdding(comp, multiplier: -1, to: candidateEnd) else { break }
      let prevStart = windowStart(for: prevEnd, range: range, allRecords: records)
      if windowContainsData(start: prevStart, end: prevEnd, in: records) {
        return prevEnd
      }
      if let earliest = records.min(by: { $0.logDate < $1.logDate })?.logDate,
        prevEnd <= earliest
      {
        break
      }
      candidateEnd = prevEnd
    }
    return nil
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
    range != .all
      && findNextWindowEnd(currentEnd: currentEnd, range: range, records: records) != nil
  }

  /// 前へ移動可能かどうか
  static func canMovePrevious(currentEnd: Date, range: RangePreset, records: [BatteryRecord])
    -> Bool
  {
    range != .all
      && findPreviousWindowEnd(currentEnd: currentEnd, range: range, records: records) != nil
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
    return .all
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

    if range == .all {
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
