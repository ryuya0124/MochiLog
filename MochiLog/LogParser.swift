import Foundation

struct LogParser {

  // 解析結果の入れ物
  struct ParseResult {
    // --- 基本 ---
    var logDate: Date?
    var osVersion: String?
    var deviceModelCode: String?

    // --- ハードウェア ---
    var storage: String?  // GB
    var ram: String?  // GB

    // --- バッテリー ---
    var cycleCount: Int?
    var designCapacity: Int?  // 設計
    var nominalCapacity: Int?  // 公称
    var rawCapacity: Int?  // 実測
    var lowRateCapacity: Int?  // 低レート

    // --- 計算値 ---
    var nominalRatio: Double?  // 公称 / 設計 (%)
    var rawRatio: Double?  // 実測 / 設計 (%)
    var lowRateRatio: Double?  // 低レート / 設計 (%)
    var deflator: Double?  // デフレータ
    var settingsDisplayPercent: Int?  // 設定上の表示

    // --- その他 ---
    var firstUseDate: Date?
    var avgTemp: Double?
    var maxTemp: Double?
    var minTemp: Double?
    var maxVoltage: Double?
    var minVoltage: Double?
    var dailyMaxSoC: Int?
    var dailyMinSoC: Int?

    var diagnosticResult: String?
  }

  // JSONデコード用の構造体（ログの中身に合わせる）
  private struct HeaderJSON: Codable {
    let timestamp: String?
    let os_version: String?
    let bug_type: String?
  }

  private struct HardwareJSON: Codable {
    let deviceCapacity: Int?  // GB
    let dramSize: Int?  // GB
  }

  private struct BatteryJSON: Codable {
    struct Message: Codable {
      let last_value_CycleCount: Int?
      let last_value_NominalChargeCapacity: Int?
      let last_value_AppleRawMaxCapacity: Int?
      let last_value_MinimumQmax: Int?
      let last_value_MaximumCapacityPercent: Int?

      let last_value_AverageTemperature: Double?
      let last_value_MaximumTemperature: Double?
      let last_value_MinimumTemperature: Double?

      let last_value_MaximumPackVoltage: Double?
      let last_value_MinimumPackVoltage: Double?

      let last_value_DailyMaxSoc: Int?
      let last_value_DailyMinSoc: Int?

      let last_value_DOFU: Double?  // UNIX Time
      let last_value_TotalOperatingTime: Double?  // おそらくHours?
    }
    let message: Message?
    // モデル名はルートにあることが多いが、headerから取るか、ここにあれば使う
    let hardwareModel: String?  // "iPhone14,2" etc
  }

  // ★メインの解析関数
  static func parse(text: String) -> ParseResult {
    var result = ParseResult()

    // 1. ヘッダー情報の取得 (timestamp, os_version)
    // timestamp はログファイルの先頭行にあるため、それ以降の行を切り捨てておく
    let headerSource = text.replacingOccurrences(
      of: "(?<=\\n).*",
      with: "",
      options: .regularExpression
    )
    if let headerMatch = findJSON(in: headerSource, containing: "timestamp"),
      let headerData = headerMatch.data(using: .utf8),
      let header = try? JSONDecoder().decode(HeaderJSON.self, from: headerData)
    {

      if let ts = header.timestamp {
        // ISO8601などの変換が必要だが、ここでは簡易的にFormatterを使用
        result.logDate = parseDate(ts)
      }
      result.osVersion = header.os_version
    }

    // 2. スペック情報の取得 (deviceCapacity, dramSize)
    if let hwMatch = findJSON(in: text, containing: "deviceCapacity"),
      let hwData = hwMatch.data(using: .utf8),
      let hw = try? JSONDecoder().decode(HardwareJSON.self, from: hwData)
    {

      if let cap = hw.deviceCapacity { result.storage = "\(cap) GB" }
      if let dram = hw.dramSize { result.ram = "\(dram) GB" }
    }

    // 3. バッテリー情報の取得
    // "NominalChargeCapacity" を含むJSONを探す。
    // ★重要: "JSONたくさんあるから最後のデータのみを取得"
    let batteryMatches = findAllJSONs(in: text, containing: "NominalChargeCapacity")

    guard let lastMatch = batteryMatches.last,
      let batData = lastMatch.data(using: .utf8),
      let batObj = try? JSONDecoder().decode(BatteryJSON.self, from: batData),
      let msg = batObj.message
    else {

      print("エラー: バッテリーデータが見つかりませんでした")
      return result
    }

    // --- 値の詰め込み ---

    // 機種名 (HardwareModel)
    let modelCode = batObj.hardwareModel
    result.deviceModelCode = modelCode

    // 設計容量の取得 (辞書から)
    let designCap = DeviceLibrary.getCapacity(for: modelCode ?? "") ?? 0
    result.designCapacity = designCap

    // 各種容量
    let nominal = msg.last_value_NominalChargeCapacity ?? 0
    let raw = msg.last_value_AppleRawMaxCapacity ?? 0
    let lowRate = msg.last_value_MinimumQmax ?? 0

    result.cycleCount = msg.last_value_CycleCount
    result.nominalCapacity = nominal
    result.rawCapacity = raw
    result.lowRateCapacity = lowRate
    result.settingsDisplayPercent = msg.last_value_MaximumCapacityPercent

    // --- 計算処理 ---

    if designCap > 0 {
      // 割合計算: (値 / 設計) * 100
      result.nominalRatio = (Double(nominal) / Double(designCap)) * 100
      result.rawRatio = (Double(raw) / Double(designCap)) * 100
      result.lowRateRatio = (Double(lowRate) / Double(designCap)) * 100
    }

    // デフレーター: 公称 / 実測
    if raw > 0 {
      result.deflator = Double(nominal) / Double(raw)
    }

    // 温度 (10で割る)
    if let avgT = msg.last_value_AverageTemperature { result.avgTemp = avgT / 10.0 }  // 平均も10で割る場合が多いが、生値による
    if let maxT = msg.last_value_MaximumTemperature { result.maxTemp = maxT / 10.0 }
    if let minT = msg.last_value_MinimumTemperature { result.minTemp = minT / 10.0 }

    // 電圧
    result.maxVoltage = msg.last_value_MaximumPackVoltage
    result.minVoltage = msg.last_value_MinimumPackVoltage

    // SoC
    result.dailyMaxSoC = msg.last_value_DailyMaxSoc
    result.dailyMinSoC = msg.last_value_DailyMinSoc

    // 初使用日 (DOFU)
    if let dofu = msg.last_value_DOFU, dofu > 0 {
      let dofuDate = Date(timeIntervalSince1970: dofu)
      // 1970/1/1の場合は無視
      if dofuDate.timeIntervalSince1970 > 86400 {
        result.firstUseDate = dofuDate
      }
    }

    // 診断結果 (簡易ロジック)
    if let health = result.rawRatio {
      if health < 80.0 {
        result.diagnosticResult = "⚠️ 交換推奨 (80%未満)"
      } else if health < 90.0 {
        result.diagnosticResult = "ℹ️ やや劣化 (90%未満)"
      } else {
        result.diagnosticResult = "✅ 正常"
      }
    }

    return result
  }

  // --- ヘルパー関数: 正規表現でJSONブロックを抽出 ---

  // 指定したキーワードを含むJSONブロック( {...} )を全て探して配列で返す
  private static func findAllJSONs(in text: String, containing keyword: String) -> [String] {
    // パターン: { (任意の文字) keyword (任意の文字) }
    // 改行を含む可能性も考慮したいが、ログ形式的に1行1JSONが多い。
    // 安全のため、行ごとにチェックして抽出する方式を採用。

    var matches: [String] = []
    let lines = text.components(separatedBy: .newlines)

    for line in lines {
      if line.contains(keyword) {
        // 行の中にJSONがあるか簡易チェック（厳密にはRegexで {.*} を抜く）
        if let start = line.firstIndex(of: "{"),
          let end = line.lastIndex(of: "}")
        {
          let jsonString = String(line[start...end])
          matches.append(jsonString)
        }
      }
    }
    return matches
  }

  // 最初の1個だけ見つける版
  private static func findJSON(in text: String, containing keyword: String) -> String? {
    let matches = findAllJSONs(in: text, containing: keyword)
    return matches.first
  }

  // 日付パース用
  private static func parseDate(_ str: String) -> Date? {
    // ISO8601 (with or without fractional seconds)
    if let date = isoFormatter.date(from: str) {
      return date
    }
    // Fallback for headers like "2025-12-22 09:00:00.00 +0900"
    for formatter in fallbackFormatters {
      if let date = formatter.date(from: str) {
        return date
      }
    }
    return nil
  }

  private static let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let fallbackFormatters: [DateFormatter] = {
    let base = DateFormatter()
    base.locale = Locale(identifier: "en_US_POSIX")
    base.timeZone = TimeZone(secondsFromGMT: 0)
    return [
      configuredFormatter(base, format: "yyyy-MM-dd HH:mm:ss.SS Z"),
      configuredFormatter(base, format: "yyyy-MM-dd HH:mm:ss.S Z"),
      configuredFormatter(base, format: "yyyy-MM-dd HH:mm:ss Z"),
    ]
  }()

  private static func configuredFormatter(_ prototype: DateFormatter, format: String)
    -> DateFormatter
  {
    let formatter = DateFormatter()
    formatter.locale = prototype.locale
    formatter.timeZone = prototype.timeZone
    formatter.dateFormat = format
    return formatter
  }
}
