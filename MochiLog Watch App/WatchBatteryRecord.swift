import Foundation

/// iPhoneとApple Watch間で共有するバッテリーレコードの軽量データモデル
/// Watch側用（BatteryRecordへの依存なし）
struct WatchBatteryRecord: Codable, Identifiable, Hashable {
  // MARK: - 識別子

  /// 一意の識別子（デバイス名と日付から生成）
  var id: String {
    "\(deviceName)_\(logDateString)"
  }

  // MARK: - プロパティ

  /// デバイス名（例: iPhone 15 Pro）
  let deviceName: String

  /// ログ日付
  let logDate: Date

  /// ログ日付の文字列表現（ID生成用）
  private var logDateString: String {
    let formatter = ISO8601DateFormatter()
    return formatter.string(from: logDate)
  }

  /// 充放電サイクル回数
  let cycleCount: Int

  /// 公称容量ベースのヘルス（%）
  let nominalHealthPercent: Double

  /// 実測容量ベースのヘルス（%）
  let healthPercent: Double

  /// 診断結果テキスト
  let diagnosticResult: String

  // MARK: - イニシャライザ

  init(
    deviceName: String,
    logDate: Date,
    cycleCount: Int,
    nominalHealthPercent: Double,
    healthPercent: Double,
    diagnosticResult: String
  ) {
    self.deviceName = deviceName
    self.logDate = logDate
    self.cycleCount = cycleCount
    self.nominalHealthPercent = nominalHealthPercent
    self.healthPercent = healthPercent
    self.diagnosticResult = diagnosticResult
  }
}
