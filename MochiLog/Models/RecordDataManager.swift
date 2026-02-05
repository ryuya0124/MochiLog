import Foundation
import SwiftData

/// レコードデータを一元管理し、複数のビュー間でデータを共有するマネージャー
/// タブ切り替え時のパフォーマンス向上のため、@Queryを一箇所に集約
@Observable
class RecordDataManager {
  /// シングルトンインスタンス
  static let shared = RecordDataManager()

  /// キャッシュされたレコード（降順：最新が先頭）
  private(set) var recordsDescending: [BatteryRecord] = []

  /// キャッシュされたレコード（昇順：古いものが先頭）
  private(set) var recordsAscending: [BatteryRecord] = []

  /// デバイス名リスト（ソート済み、計算結果をキャッシュ）
  private(set) var deviceNames: [String] = []

  /// 最後に更新したレコードのハッシュ値（不要な更新を防止）
  private var lastRecordsHash: Int?

  private init() {}

  /// レコードを更新（降順で受け取る想定）
  func updateRecords(_ newRecords: [BatteryRecord]) {
    // ハッシュ値を計算して変更を検知
    var hasher = Hasher()
    hasher.combine(newRecords.count)
    if let first = newRecords.first {
      hasher.combine(first.logDate)
      hasher.combine(first.deviceName)
    }
    if let last = newRecords.last {
      hasher.combine(last.logDate)
      hasher.combine(last.deviceName)
    }
    let newHash = hasher.finalize()

    // 変更がなければスキップ
    if newHash == lastRecordsHash {
      print("[Performance] RecordDataManager.updateRecordsスキップ（データ未変更）")
      return
    }

    print("[Performance] RecordDataManager.updateRecords実行（\(newRecords.count)件）")

    recordsDescending = newRecords
    recordsAscending = newRecords.reversed()

    // デバイス名リストを更新
    deviceNames = Array(Set(newRecords.map { $0.deviceName })).sorted()

    lastRecordsHash = newHash
  }

  /// レコード数を取得
  var count: Int {
    recordsDescending.count
  }

  /// レコードが空かどうか
  var isEmpty: Bool {
    recordsDescending.isEmpty
  }
}
