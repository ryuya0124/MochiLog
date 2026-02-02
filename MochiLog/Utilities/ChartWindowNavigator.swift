import Foundation

// MARK: - グラフウィンドウナビゲーションユーティリティ
/// グラフの期間移動に関する共通ロジック
struct ChartWindowNavigator {

  // MARK: - 共通チャート計算

  /// レンジに応じた実効レンジを決定（autoの場合のみ）
  static func effectiveRange(for recordDates: [Date], range: RangePreset) -> RangePreset {
    guard range == .auto else { return range }
    let now = Date()
    let pastDates = recordDates.filter { $0 <= now }
    let sourceDates = pastDates.isEmpty ? recordDates : pastDates
    return autoRange(forDates: sourceDates)
  }

  /// レンジに応じた実効終了日を決定（autoの場合のみ、未来日を回避）
  static func effectiveEndDate(
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

  /// recordDatesに基づいてウィンドウ開始・終了日と表示単位を計算
  static func computeChartWindow(
    recordDates: [Date],
    windowEnd: Date,
    range: RangePreset
  ) -> (startDay: Date, endDay: Date, unit: AppSettings.ChartUnit) {
    let calendar = Calendar.current
    let effectiveRange = effectiveRange(for: recordDates, range: range)
    let effectiveEnd = effectiveEndDate(for: recordDates, windowEnd: windowEnd, range: range)
    let startDate = windowStart(for: effectiveEnd, range: effectiveRange, allRecords: [])
    let startDay = calendar.startOfDay(for: startDate)
    let endDay = calendar.startOfDay(for: effectiveEnd)

    let visibleDates = recordDates.filter {
      let d = calendar.startOfDay(for: $0)
      return d >= startDay && d <= endDay
    }

    let unit = autoUnit(forDates: visibleDates, startDay: startDay, endDay: endDay)
    return (startDay, endDay, unit)
  }

  /// レンジ変更時の終了日を共通で算出
  static func adjustedWindowEndForRangeChange(
    range: RangePreset,
    currentEnd: Date,
    records: [BatteryRecord]
  ) -> Date {
    let now = Date()

    switch range {
    case .oneMonth:
      let endOfCurrentMonth = endOfMonth(for: now)
      let start = windowStart(for: endOfCurrentMonth, range: range, allRecords: records)
      if windowContainsData(start: start, end: endOfCurrentMonth, in: records) {
        return endOfCurrentMonth
      }
      return initializeWindowEnd(for: records, range: range)
    case .threeMonths:
      return endOfQuarter(for: now)
    case .sixMonths:
      return endOfHalfYear(for: now)
    case .oneYear:
      return endOfYear(for: now)
    default:
      let start = windowStart(for: currentEnd, range: range, allRecords: records)
      if windowContainsData(start: start, end: currentEnd, in: records) {
        return currentEnd
      }
      return initializeWindowEnd(for: records, range: range)
    }
  }

  // MARK: - 期間コンポーネント

  /// 選択されたレンジに対応するDateComponentsを返す
  static func periodComponent(for preset: RangePreset) -> DateComponents? {
    switch preset {
    case .auto:
      return nil
    case .oneWeek:
      return DateComponents(day: 7)
    case .twoWeeks:
      return DateComponents(day: 14)
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
    case .auto:
      // 自動：データ分布に応じた実効レンジを適用
      let effectiveRange = autoRange(for: allRecords)
      return windowStart(for: endDate, range: effectiveRange, allRecords: allRecords)
    case .oneWeek:
      return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
    case .twoWeeks:
      return calendar.date(byAdding: .day, value: -14, to: endDate) ?? endDate
    case .oneMonth:
      // カレンダー月に固定：終了日の月の1日を開始日とする
      let components = calendar.dateComponents([.year, .month], from: endDate)
      return calendar.date(from: components) ?? endDate
    case .threeMonths:
      // 四半期境界に固定：Q1(1-3月), Q2(4-6月), Q3(7-9月), Q4(10-12月)
      let month = calendar.component(.month, from: endDate)
      let year = calendar.component(.year, from: endDate)
      let quarterStartMonth = ((month - 1) / 3) * 3 + 1  // 1, 4, 7, 10
      var components = DateComponents()
      components.year = year
      components.month = quarterStartMonth
      components.day = 1
      return calendar.date(from: components) ?? endDate
    case .sixMonths:
      // 半年基準：前半（1-6月）か後半（7-12月）の開始月を返す
      let month = calendar.component(.month, from: endDate)
      let year = calendar.component(.year, from: endDate)
      var components = DateComponents()
      components.year = year
      components.month = month <= 6 ? 1 : 7  // 前半なら1月、後半なら7月
      components.day = 1
      return calendar.date(from: components) ?? endDate
    case .oneYear:
      // カレンダー年に固定：終了日の年の1月1日を開始日とする
      let components = calendar.dateComponents([.year], from: endDate)
      return calendar.date(from: components) ?? endDate
    case .twoYears:
      // 2年前の1月1日を開始日とする
      let year = calendar.component(.year, from: endDate)
      var components = DateComponents()
      components.year = year - 1
      components.month = 1
      components.day = 1
      return calendar.date(from: components) ?? endDate
    case .threeYears:
      // 2年前の1月1日を開始日とする（3年分表示）
      let year = calendar.component(.year, from: endDate)
      var components = DateComponents()
      components.year = year - 2
      components.month = 1
      components.day = 1
      return calendar.date(from: components) ?? endDate
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

  /// 指定した日付が含まれる月の末日を取得
  static func endOfMonth(for date: Date) -> Date {
    let calendar = Calendar.current
    // 月の1日を取得
    let components = calendar.dateComponents([.year, .month], from: date)
    guard let firstOfMonth = calendar.date(from: components) else { return date }
    // 翌月の1日から1日引いて末日を取得
    guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth),
      let endOfMonth = calendar.date(byAdding: .day, value: -1, to: nextMonth)
    else {
      return date
    }
    return endOfMonth
  }

  /// 指定した日付が含まれる年の末日（12月31日）を取得
  static func endOfYear(for date: Date) -> Date {
    let calendar = Calendar.current
    // 年の1月1日を取得
    var components = calendar.dateComponents([.year], from: date)
    components.month = 12
    components.day = 31
    return calendar.date(from: components) ?? date
  }

  /// 指定した日付が含まれる四半期の末日を取得
  static func endOfQuarter(for date: Date) -> Date {
    let calendar = Calendar.current
    let month = calendar.component(.month, from: date)
    let year = calendar.component(.year, from: date)
    // 四半期の最終月を計算（3, 6, 9, 12）
    let quarterEndMonth = ((month - 1) / 3 + 1) * 3
    var components = DateComponents()
    components.year = year
    components.month = quarterEndMonth + 1  // 翌月の1日
    components.day = 1
    guard let firstOfNextMonth = calendar.date(from: components),
      let endOfQuarter = calendar.date(byAdding: .day, value: -1, to: firstOfNextMonth)
    else {
      return date
    }
    return endOfQuarter
  }

  /// 指定した日付が含まれる半年（四半期2つ分）の末日を取得
  /// 1-6月 → 6月30日、7-12月 → 12月31日
  static func endOfHalfYear(for date: Date) -> Date {
    let calendar = Calendar.current
    let month = calendar.component(.month, from: date)
    let year = calendar.component(.year, from: date)

    // 前半（1-6月）か後半（7-12月）かを判定
    if month <= 6 {
      // 前半 → 6月30日
      var components = DateComponents()
      components.year = year
      components.month = 6
      components.day = 30
      return calendar.date(from: components) ?? date
    } else {
      // 後半 → 12月31日
      var components = DateComponents()
      components.year = year
      components.month = 12
      components.day = 31
      return calendar.date(from: components) ?? date
    }
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

    // 1ヶ月表示の場合はカレンダー月単位でナビゲート
    if range == .oneMonth {
      return endOfMonth(for: nextDataDate)
    }

    // 3ヶ月表示の場合は四半期単位でナビゲート
    if range == .threeMonths {
      return endOfQuarter(for: nextDataDate)
    }

    // 1年/2年/3年表示の場合はカレンダー年単位でナビゲート
    if range == .oneYear || range == .twoYears || range == .threeYears {
      return endOfYear(for: nextDataDate)
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

    // 1ヶ月表示の場合はカレンダー月単位でナビゲート
    if range == .oneMonth {
      return endOfMonth(for: prevDataDate)
    }

    // 3ヶ月表示の場合は四半期単位でナビゲート
    if range == .threeMonths {
      return endOfQuarter(for: prevDataDate)
    }

    // 1年/2年/3年表示の場合はカレンダー年単位でナビゲート
    if range == .oneYear || range == .twoYears || range == .threeYears {
      return endOfYear(for: prevDataDate)
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
    if days <= 14 { return .twoWeeks }
    if days <= 30 { return .oneMonth }
    if days <= 90 { return .threeMonths }
    if days <= 180 { return .sixMonths }
    if days <= 365 { return .oneYear }
    if days <= 730 { return .twoYears }
    return .threeYears
  }

  /// 日付配列に基づいて初期レンジを決定
  static func autoRange(forDates recordDates: [Date]) -> RangePreset {
    guard let first = recordDates.min(), let last = recordDates.max() else { return .oneMonth }
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
    if days <= 120 { return .day }
    if days <= 730 { return .week }
    return .month
  }

  /// 日付配列に基づいて表示単位を決定
  static func autoUnit(forDates dates: [Date], startDay: Date, endDay: Date)
    -> AppSettings.ChartUnit
  {
    let calendar = Calendar.current
    let days = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    let count = dates.count

    if days <= 2 && count > 24 { return .hour }
    if days <= 14 { return .day }
    if days <= 120 { return .day }
    if days <= 730 { return .week }
    return .month
  }

  // MARK: - ウィンドウ終了日初期化

  /// レコードに基づいてウィンドウ終了日を初期化
  static func initializeWindowEnd(for records: [BatteryRecord], range: RangePreset) -> Date {
    guard !records.isEmpty else { return Date() }

    let now = Date()

    // 1ヶ月選択時は月末を終了日とする（完全な1ヶ月を表示）
    if range == .oneMonth {
      return endOfMonth(for: now)
    }

    // 3ヶ月選択時は四半期末を終了日とする（完全な四半期を表示）
    if range == .threeMonths {
      return endOfQuarter(for: now)
    }

    // 6ヶ月選択時は半年末を終了日とする（四半期2つ分、完全な半年を表示）
    if range == .sixMonths {
      return endOfHalfYear(for: now)
    }

    // 1年選択時は年末を終了日とする（完全な1年を表示）
    if range == .oneYear {
      return endOfYear(for: now)
    }

    // 3年選択時は最新データの日付を終了日とする
    if range == .threeYears {
      return records.max(by: { $0.logDate < $1.logDate })?.logDate ?? Date()
    }

    // その他のレンジ：現在日付のウィンドウにデータがあれば今日、なければ最新データの日付
    let startNow = windowStart(for: now, range: range, allRecords: records)
    if windowContainsData(start: startNow, end: now, in: records) {
      return now
    }

    return records.max(by: { $0.logDate < $1.logDate })?.logDate ?? now
  }
}
